"use strict";
const Amaz = effect.Amaz;

const SCRIPT_NAME = "idol";
const MAX_FACE_COUNT = 2;
const DEFAULT_MALE_INTENSITY = 1;

/**
 * @field {String} Channel - {
 *    "display": "combobox",
 *    "label": "component_gan_channel",
 *    "default": "Texture",
 *    "options": [
 *        {"label": "component_gan_channel_texture",   "value": "Texture"},
 *        {"label": "component_gan_channel_distortion",   "value": "Distortion"}
 *     ]
 * }
 * @field {Number} Intensity - {
 *    "display": "slider",
 *    "label": "component_gan_intensity",
 *    "default": 1.0,
 *    "step": 0.1,
 *    "precision": 2,
 *    "range": { "min": 0, "max": 1.0 },
 *    "showIf": "Channel",
 *    "showIfValue": "Distortion"
 * }
 * @field {Number} Transparency - {
 *    "display": "slider",
 *    "label": "component_gan_transparency",
 *    "default": 1.0,
 *    "step": 0.1,
 *    "precision": 2,
 *    "range": { "min": 0, "max": 1.0 },
 *    "showIf": "Channel",
 *    "showIfValue": "Texture"
 * }
 */
class idol {
  constructor() {
    this.name = "idol";
    this.ganTextureUniform = "ganTexture";
    this.flowTextureUniform = "flowTexture";
    this.ganTransform = "mvpMat";
    this.enableUniform = "enable";
    this.isGanUniform = "isGan";
    this.flowLevelUniform = "flowLevel";
    this.alphaMutUniform = "alphaMut";
    this.transparencyUniform = "transparency";
    this.ganCamera = null;

    this.materialPath = "idol/gan.material";
    this.materialList = [];
    this.cbList = {
      0: new Amaz.CommandBuffer(),
      1: new Amaz.CommandBuffer(),
    };
    this.activeFaceCount = 0;
    this.dstCopy = null;
    this.graphName = "";
    this.MeshRender = undefined;
    this.ganEnabled = false;

    this.preChannel = "";
  }

  onStart() {
    if (this.ganMaskPath) {
      this.ganMask = this.scene.assetMgr.SyncLoad(this.ganMaskPath);
    }
    this._initMaterialList(MAX_FACE_COUNT);

    const parentTrans = this.entity.getComponent("Transform").parent;
    for (let i = 0; i < parentTrans.children.size(); i++) {
      const child = parentTrans.children.get(i);
      if (child.entity.getComponent("Camera")) {
        this.ganCamera = child.entity.getComponent("Camera");
        this.script.addScriptListener(
          this.ganCamera,
          Amaz.CameraEvent.RENDER_IMAGE_EFFECTS,
          "renderGANEffects",
          this.script,
        );
        let colorFormat = Amaz.PixelFormat.RGBA8Unorm;
        if (
          this.ganCamera.renderTexture.realColorFormat ===
            Amaz.PixelFormat.RGBA16Sfloat ||
          this.ganCamera.renderTexture.realColorFormat ===
            Amaz.PixelFormat.RGBA32Sfloat
        ) {
          colorFormat = this.ganCamera.renderTexture.colorFormat;
        }
        this.dstCopy = this.createRenderTexture(
          "dstCopy",
          this.ganCamera.renderTexture.width,
          this.ganCamera.renderTexture.height,
          colorFormat,
        );
        break;
      }
    }

    this._updateCommandBuffers();
  }

  _initMaterialList(count) {
    this.materialList = [];
    for (let i = 0; i < count; i++) {
      const material = this.scene.assetMgr
        .SyncLoad(this.materialPath)
        .instantiate();
      const tex = new Amaz.Texture2D();
      material.setTex(this.ganTextureUniform, tex);
      material.setFloat(this.enableUniform, 0);
      if (this.maskTextureUniform && this.ganMask) {
        material.setTex(this.maskTextureUniform, this.ganMask);
      }
      this.materialList.push(material);
    }
  }

  _updateCommandBuffers() {
    if (!this.ganCamera || !this.dstCopy) {
      return;
    }

    const oneFaceCb = this.cbList[0];
    oneFaceCb.clearAll();
    oneFaceCb.blit(this.ganCamera.renderTexture, this.dstCopy);
    oneFaceCb.blitWithMaterial(
      this.dstCopy,
      this.ganCamera.renderTexture,
      this.materialList[0],
      0,
    );

    const twoFaceCb = this.cbList[1];
    twoFaceCb.clearAll();
    twoFaceCb.blit(this.ganCamera.renderTexture, this.dstCopy);
    twoFaceCb.blitWithMaterial(
      this.dstCopy,
      this.ganCamera.renderTexture,
      this.materialList[0],
      0,
    );
    twoFaceCb.blit(this.ganCamera.renderTexture, this.dstCopy);
    twoFaceCb.blitWithMaterial(
      this.dstCopy,
      this.ganCamera.renderTexture,
      this.materialList[1],
      0,
    );
  }

  _getSelfJsComp() {
    const jsScriptComps = this.entity.getComponents("JSScriptComponent");
    for (let i = 0; i < jsScriptComps.size(); i++) {
      const comp = jsScriptComps.get(i);
      const className = comp.getScript().className;
      if (className === this.script.className) {
        return comp;
      }
    }
  }

  _getMaleIntensity() {
    const jsComp = this._getSelfJsComp();
    let maleIntensity = DEFAULT_MALE_INTENSITY;

    if (jsComp && jsComp.properties) {
      maleIntensity = jsComp.properties.get("maleIntensity");
    }

    if (maleIntensity !== null && maleIntensity !== undefined) {
      return maleIntensity;
    }
    return DEFAULT_MALE_INTENSITY;
  }

  _getGender(algoResult, faceIndex) {
    const expressionCount = algoResult.getFaceAttributeCount();
    if (expressionCount <= 0 || faceIndex < 0 || faceIndex >= expressionCount) {
      return 0;
    }
    const carInfo = algoResult.getFaceAttributeInfo(faceIndex);
    return carInfo.gender;
  }

  _getAlphaMut(gender) {
    if (gender === 1) {
      return this._getMaleIntensity();
    }
    return 1.0;
  }

  _getFaceTextures(algoResult, graphName, nodeName, faceIndex) {
    const textureStridePerFace = 2;
    const ganTextureIndex = faceIndex * textureStridePerFace;
    const flowTextureIndex = ganTextureIndex + 1;
    return {
      ganTex: this.getGanTexture(
        algoResult,
        graphName,
        nodeName,
        ganTextureIndex,
      ),
      flowTex: this.getGanTexture(
        algoResult,
        graphName,
        nodeName,
        flowTextureIndex,
      ),
    };
  }

  _bindFaceToMaterial(result, faceIndex, material) {
    const faceTextures = this._getFaceTextures(
      result,
      this.graphName,
      "script_0",
      faceIndex,
    );
    const tfmInfo = result.getNHImageTfmInfo(
      this.graphName,
      "FaceAlign",
      faceIndex,
    );

    if (!faceTextures.ganTex || !faceTextures.flowTex || !tfmInfo) {
      material.setFloat(this.enableUniform, 0);
      return false;
    }

    material.setMat4(this.ganTransform, tfmInfo.mvp);
    material.setTex(this.ganTextureUniform, faceTextures.ganTex);
    material.setTex(this.flowTextureUniform, faceTextures.flowTex);
    material.setFloat(this.enableUniform, 1);
    material.setFloat(this.isGanUniform, this.Channel === "Distortion" ? 0 : 1);
    material.setFloat(this.flowLevelUniform, this.Intensity);
    material.setFloat(
      this.alphaMutUniform,
      this._getAlphaMut(this._getGender(result, faceIndex)),
    );
    material.setFloat(this.transparencyUniform, this.Transparency);
    return true;
  }

  getGanTexture(algoResult, graphName, nodeName, index) {
    const info = algoResult.getOutputTexture(graphName, nodeName, index, 1);
    if (info !== null && info !== undefined) {
      const ganTex = info.texture;
      if (ganTex !== null && ganTex !== undefined) {
        return ganTex;
      }
    }

    const legacyInfo = algoResult.getAlgorithmInfo(graphName, nodeName, "", index);
    if (legacyInfo === null || legacyInfo === undefined) {
      return null;
    }

    const legacyTex = legacyInfo.texture;
    if (legacyTex === null || legacyTex === undefined) {
      return null;
    }
    return legacyTex;
  }

  show() {
    const Algorithm = Amaz.AmazingManager.getSingleton("Algorithm");
    const result = Algorithm.getAEAlgorithmResult(this.graphName);
    if (!result) {
      this.activeFaceCount = 0;
      this.ganEnabled = false;
      for (let i = 0; i < MAX_FACE_COUNT; i++) {
        this.materialList[i].setFloat(this.enableUniform, 0);
      }
      return;
    }

    const transform = this.entity.getComponent("Transform");
    if (transform === undefined) {
      console.error("transform is undefined");
    } else {
      transform.worldOrientation = new Amaz.Vector3f(0, 0, 0);
      transform.worldPosition = new Amaz.Vector3f(0, 0, 0);
      transform.worldScale = new Amaz.Vector3f(1, 1, 1);
    }

    const detectedFaceCount = Math.min(
      MAX_FACE_COUNT,
      Math.max(0, result.getFaceAttributeCount()),
    );

    let validFaceCount = 0;
    for (let faceIndex = 0; faceIndex < detectedFaceCount; faceIndex++) {
      const isValid = this._bindFaceToMaterial(
        result,
        faceIndex,
        this.materialList[faceIndex],
      );
      if (isValid) {
        validFaceCount += 1;
      }
    }

    for (
      let faceIndex = detectedFaceCount;
      faceIndex < MAX_FACE_COUNT;
      faceIndex++
    ) {
      this.materialList[faceIndex].setFloat(this.enableUniform, 0);
    }

    this.activeFaceCount = validFaceCount;
    this.ganEnabled = validFaceCount > 0;
  }

  onUpdate(deltaTime) {
    if (this.preChannel !== this.Channel && this.ganCamera && this.dstCopy) {
      this._updateCommandBuffers();
      this.preChannel = this.Channel;
    }

    this.show();
  }

  onDestroy(sys) {
    if (this.ganCamera !== null) {
      this.script.removeScriptListener(
        this.ganCamera,
        Amaz.CameraEvent.RENDER_IMAGE_EFFECTS,
        "renderGANEffects",
        this.script,
      );
    }
  }

  renderGANEffects(sys, camera, eventType) {
    if (
      camera.entity.visible &&
      camera.enabled &&
      this.entity.visible &&
      this.ganEnabled &&
      eventType === Amaz.CameraEvent.RENDER_IMAGE_EFFECTS
    ) {
      const faceCount = Math.min(MAX_FACE_COUNT, this.activeFaceCount);
      if (faceCount >= 2) {
        camera.entity.scene.commitCommandBuffer(this.cbList[1]);
      } else if (faceCount === 1) {
        camera.entity.scene.commitCommandBuffer(this.cbList[0]);
      }
    }
  }

  createRenderTexture(name, width, height, colorFormat) {
    const rt = new Amaz.RenderTexture();
    rt.name = name;
    rt.builtinType = Amaz.BuiltInTextureType.NORMAL;
    rt.internalFormat = Amaz.InternalFormat.RGBA8;
    rt.dataType = Amaz.DataType.U8norm;
    rt.depth = 1;
    rt.attachment = Amaz.RenderTextureAttachment.DEPTH24;
    rt.filterMag = Amaz.FilterMode.LINEAR;
    rt.filterMin = Amaz.FilterMode.LINEAR;
    rt.filterMipmap = Amaz.FilterMipmapMode.FilterMode_NONE;
    rt.width = width;
    rt.height = height;
    rt.colorFormat = colorFormat || Amaz.PixelFormat.RGBA8Unorm;
    return rt;
  }

  onEnable() {
    this.ganEnabled = true;
    this.dynamicSetAlgorithmEnable(true);
  }

  onDisable() {
    this.ganEnabled = false;
    this.dynamicSetAlgorithmEnable(false);
  }

  dynamicSetAlgorithmEnable(enable) {
    const Algorithm = Amaz.AmazingManager.getSingleton("Algorithm");
    const algoList = [
      "blit_0",
      "face_0",
      "expression_detect_0",
      "FaceAlign",
      "script_0",
    ];
    if (enable) {
      for (let i = 0; i < algoList.length; ++i) {
        Algorithm.setAlgorithmEnable(this.graphName, algoList[i], true);
      }
    } else {
      for (let i = algoList.length - 1; i >= 0; --i) {
        Algorithm.setAlgorithmEnable(this.graphName, algoList[i], false);
      }
    }
  }
}

exports.idol = idol;
