#!/usr/bin/env python3
"""
Convert a TorchScript or ONNX model into a Core ML .mlpackage for AudioSplitter.

Dependencies:
  - coremltools
  - torch
  - numpy

Optional (only for ONNX input):
  - onnx
  - onnx2torch
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def parse_shape(raw: str) -> tuple[int, int, int, int]:
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("Shape must contain exactly 4 comma-separated integers.")
    try:
        dims = tuple(int(part) for part in parts)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("Shape must contain integers.") from exc
    if any(value <= 0 for value in dims):
        raise argparse.ArgumentTypeError("All shape dimensions must be > 0.")
    return dims  # type: ignore[return-value]


def resolve_output_path(raw: str) -> Path:
    path = Path(raw)
    if path.suffix != ".mlpackage":
        path = path.with_suffix(".mlpackage")
    return path


def load_source_model(source: Path, shape: tuple[int, int, int, int]):
    import torch

    suffix = source.suffix.lower()
    if suffix == ".onnx":
        try:
            import onnx
            from onnx2torch import convert as onnx_to_torch
        except ImportError as exc:
            raise RuntimeError(
                "ONNX input requires optional dependencies 'onnx' and 'onnx2torch'. "
                "Install them, or provide a TorchScript model."
            ) from exc

        onnx_model = onnx.load(str(source))
        torch_model = onnx_to_torch(onnx_model)
        torch_model.eval()

        example = torch.randn(*shape, dtype=torch.float32)
        with torch.no_grad():
            _ = torch_model(example)

        traced = torch.jit.trace(torch_model, example, strict=False)
        traced.eval()
        return traced, "onnx2torch + torch.jit.trace"

    model = torch.jit.load(str(source), map_location="cpu")
    model.eval()
    return model, "torch.jit.load"


def convert_model(
    source: Path,
    output: Path,
    input_name: str,
    shape: tuple[int, int, int, int],
    min_ios: str,
    precision: str,
    author: str,
    short_description: str,
    model_license: str,
    skip_metadata_check: bool,
) -> int:
    try:
        import coremltools as ct
        import numpy as np
    except ImportError:
        print("Missing dependency: coremltools and/or numpy", file=sys.stderr)
        return 2

    try:
        source_model, loader = load_source_model(source, shape)
    except Exception as exc:  # pylint: disable=broad-except
        print(f"Failed to load source model: {exc}", file=sys.stderr)
        return 2

    target_map = {}
    for target_name in ("iOS16", "iOS17", "iOS18"):
        target_value = getattr(ct.target, target_name, None)
        if target_value is not None:
            target_map[target_name] = target_value
    if min_ios not in target_map:
        available = ", ".join(sorted(target_map.keys())) or "none"
        print(
            f"coremltools does not support requested deployment target {min_ios}. "
            f"Available targets: {available}",
            file=sys.stderr,
        )
        return 2
    precision_map = {
        "float16": ct.precision.FLOAT16,
        "float32": ct.precision.FLOAT32,
    }

    output.parent.mkdir(parents=True, exist_ok=True)

    print(f"Loaded source model using: {loader}")
    print(f"Converting {source} -> {output}")

    try:
        mlmodel = ct.convert(
            source_model,
            convert_to="mlprogram",
            inputs=[ct.TensorType(name=input_name, shape=shape, dtype=np.float32)],
            minimum_deployment_target=target_map[min_ios],
            compute_precision=precision_map[precision],
        )
    except Exception as exc:  # pylint: disable=broad-except
        print(f"Conversion failed: {exc}", file=sys.stderr)
        return 2

    # Fill metadata so generated packages are easier to audit.
    mlmodel.author = author
    mlmodel.short_description = short_description
    mlmodel.license = model_license
    mlmodel.user_defined_metadata["com.audiosplitter.source_model"] = str(source)
    mlmodel.user_defined_metadata["com.audiosplitter.input_name"] = input_name
    mlmodel.user_defined_metadata["com.audiosplitter.input_shape"] = str(list(shape))
    mlmodel.user_defined_metadata["com.audiosplitter.converter_script"] = "scripts/convert_model_to_mlpackage.py"

    try:
        mlmodel.save(str(output))
    except Exception as exc:  # pylint: disable=broad-except
        print(f"Failed to save model package: {exc}", file=sys.stderr)
        return 2

    print("Saved Core ML package successfully.")

    if skip_metadata_check:
        return 0

    print("Running coremlcompiler metadata check...")
    check = subprocess.run(
        ["xcrun", "coremlcompiler", "metadata", str(output)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if check.returncode != 0:
        print(check.stdout, file=sys.stderr)
        print("Metadata check failed. The package was still written.", file=sys.stderr)
        return 1

    print(check.stdout)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert TorchScript or ONNX source models to Core ML .mlpackage."
    )
    parser.add_argument(
        "--source",
        required=True,
        help="Path to source model (.pt/.ts TorchScript or .onnx).",
    )
    parser.add_argument(
        "--output",
        default="AudioSplitter/UVRMDXNet.mlpackage",
        help="Output model package path (default: AudioSplitter/UVRMDXNet.mlpackage).",
    )
    parser.add_argument(
        "--input-name",
        default="input",
        help="Input tensor name expected by the app (default: input).",
    )
    parser.add_argument(
        "--shape",
        type=parse_shape,
        default=(1, 4, 2560, 256),
        help="Input tensor shape as comma-separated ints (default: 1,4,2560,256).",
    )
    parser.add_argument(
        "--min-ios",
        choices=["iOS16", "iOS17", "iOS18"],
        default="iOS17",
        help="Minimum iOS deployment target for the generated model.",
    )
    parser.add_argument(
        "--precision",
        choices=["float16", "float32"],
        default="float16",
        help="Core ML compute precision.",
    )
    parser.add_argument(
        "--author",
        default="AudioSplitter contributors",
        help="Core ML metadata author field.",
    )
    parser.add_argument(
        "--description",
        default="UVR-compatible stem separation model for AudioSplitter.",
        help="Core ML metadata short_description field.",
    )
    parser.add_argument(
        "--model-license",
        default="Check original model source license terms.",
        help="Core ML metadata license field.",
    )
    parser.add_argument(
        "--skip-metadata-check",
        action="store_true",
        help="Skip xcrun coremlcompiler metadata validation.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    source = Path(args.source)
    if not source.exists():
        print(f"Source model not found: {source}", file=sys.stderr)
        return 2

    output = resolve_output_path(args.output)
    return convert_model(
        source=source,
        output=output,
        input_name=args.input_name,
        shape=args.shape,
        min_ios=args.min_ios,
        precision=args.precision,
        author=args.author,
        short_description=args.description,
        model_license=args.model_license,
        skip_metadata_check=args.skip_metadata_check,
    )


if __name__ == "__main__":
    raise SystemExit(main())
