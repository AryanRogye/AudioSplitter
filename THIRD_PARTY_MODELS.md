# Third-Party Model Notes

AudioSplitter code is MIT-licensed (see `LICENSE`), but model weights are separate artifacts and can have different licenses/terms.

## UVR MDX Models

- Upstream project: `Anjok07/ultimatevocalremovergui`
- UVR code license: MIT
- Common model download source used by UVR: `TRvlvr/model_repo` release assets

Before distributing model files (including converted `.mlpackage` files), verify the source model license and redistribution terms.

## Attribution Template

When using UVR models, include attribution like:

`This app uses UVR/MDX source-separation models. Credit: Ultimate Vocal Remover (UVR) and contributors.`

You can include links in your app/site/repo:

- https://github.com/Anjok07/ultimatevocalremovergui
- https://github.com/TRvlvr/model_repo/releases/tag/all_public_uvr_models

## Important

Model conversion does not change underlying rights. A converted Core ML package is still governed by the original model's license/terms.
