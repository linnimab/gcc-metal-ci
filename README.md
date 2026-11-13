# GoodColorCam Metal CI

Pure-Metal iOS build mirror. No vendor binaries (AwemeCore / EffectSDK / TTFFmpeg / boringssl).

Trigger `build-metal-ipa` manually; the unsigned and ad-hoc signed IPAs appear in the run's artifacts and Release.

For stock iOS devices, re-sign `GoodColorCam-metal-adhoc.ipa` with your own certificate/profile.
