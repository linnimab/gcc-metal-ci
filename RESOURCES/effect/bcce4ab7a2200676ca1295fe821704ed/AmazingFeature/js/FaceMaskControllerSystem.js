'use strict';

const Amaz = effect.Amaz;
const k_opacityName = '_Opacity';
const k_faceModelName = '_faceModel';
const k_eyeModelName = '_eyeModel';
const k_lipModelName = '_lipModel';

class FaceMaskControllerSystem {
  constructor() {
    this.faceMaskCompMap = new Map();
    this.meshRendererMap = new Map();
    this.algorithmManager = null;
    this.genderReg = false;
    this.faceRotationScale = 0.3;
    this.eyeRotationScale = 0.5;
    this.lipRotationScale = 0.3;
    this.needUpdateFaceModel = false;
    this.needUpdateEyeModel = false;
    this.needUpdateLipModel = false;
  }

  onInit() {
    this.script.handleComponentName('EffectFaceMakeup');
    this.script.handleComponentName('EffectFaceMakeupFaceU');
  }

  onStart() {
    this.algorithmManager = Amaz.AmazingManager.getSingleton('Algorithm');
    this.algorithmManager.setAlgorithmParamInt('', 'expression_detect_0', 'face_attr_force_detect', 1);
    for (const v of this.meshRendererMap) {
      v[1].entirePingPong = true;
      if (v[1].materials) {
        const makeupMaterial = v[1].materials.get(0);
        if (makeupMaterial) {
          if (makeupMaterial.getMat4(k_faceModelName) !== null) {
            this.needUpdateFaceModel = true;
          }
          if (makeupMaterial.getMat4(k_eyeModelName) !== null) {
            this.needUpdateEyeModel = true;
          }
          if (makeupMaterial.getMat4(k_lipModelName) !== null) {
            this.needUpdateLipModel = true;
          }
        }
      }
    }
  }

  onComponentAdded(comp) {
    if (comp.isInstanceOf('EffectFaceMakeup') && comp.componentVersion === 3 && !comp.isInstanceOf('EffectFacePupilV2')) {
      const guid = comp.guid.toString();
      this.faceMaskCompMap.set(guid, comp);
      const meshRenderer = comp.entity.getComponent('MeshRenderer');
      if (meshRenderer) {
        this.meshRendererMap.set(guid, meshRenderer);
      }
      if (comp.isInstanceOf('EffectFaceMakeupFaceU')) {
        comp.xoffset = 1.0;
        comp.yoffset = 1.0;
      }
    }
  }

  onComponentRemoved(comp) {
    if (comp.isInstanceOf('EffectFaceMakeup') && comp.componentVersion === 3 && !comp.isInstanceOf('EffectFacePupilV2')) {
      const guid = comp.guid.toString();
      this.faceMaskCompMap.delete(guid);
      this.meshRendererMap.delete(guid);
    }
  }

  onUpdate(dt) {
    const result = this.algorithmManager.getAEAlgorithmResult();
    if (result !== null) {
      const faceCount = result.getFaceCount();
      for (let i = 0; i < faceCount; ++i) {
        const faceAttr = result.getFaceAttributeInfo(i);
        if (faceAttr !== null) {
          if (!this.genderReg) {
            this.algorithmManager.setAlgorithmParamInt('', 'expression_detect_0', 'face_attr_force_detect', 0);
            this.genderReg = true;
          }
          const baseInfo = result.getFaceBaseInfo(i);
          const faceMatrix = this._getRotationMatrix(baseInfo, this.faceRotationScale, this.needUpdateFaceModel);
          const eyeMatrix = this._getRotationMatrix(baseInfo, this.eyeRotationScale, this.needUpdateEyeModel);
          const lipMatrix = this._getRotationMatrix(baseInfo, this.lipRotationScale, this.needUpdateLipModel);
          this.faceMaskCompMap.forEach((makeup, key) => {
            if (this.needUpdateFaceModel || this.needUpdateEyeModel || this.needUpdateLipModel) {
              const meshrenderer = this.meshRendererMap.get(key);
              const makeupMaterials = meshrenderer.materials;
              if (meshrenderer && makeupMaterials) {
                const makeupMaterial = makeupMaterials.get(i);
                if (makeupMaterial) {
                  if (makeupMaterial.getMat4(k_faceModelName) !== null) {
                    makeupMaterial.setMat4(k_faceModelName, faceMatrix);
                  }
                  if (makeupMaterial.getMat4(k_eyeModelName) !== null) {
                    makeupMaterial.setMat4(k_eyeModelName, eyeMatrix);
                  }
                  if (makeupMaterial.getMat4(k_lipModelName) !== null) {
                    makeupMaterial.setMat4(k_lipModelName, lipMatrix);
                  }
                }
              }
            }
            if (faceAttr.gender === 1) {
              makeup.setFaceUniform(k_opacityName, i, makeup['maleOpacity']);
            } else if (faceAttr.gender === 2) {
              makeup.setFaceUniform(k_opacityName, i, makeup['femaleOpacity']);
            }
          });
        }
      }
    }
  }

  _getRotationMatrix(baseInfo, rotationScale, needUpdate) {
    if (needUpdate && baseInfo !== null) {
      const faceEuler = new Amaz.Vector3f();
      faceEuler.x = baseInfo.pitch * rotationScale;
      faceEuler.y = -baseInfo.yaw * rotationScale;
      faceEuler.z = baseInfo.roll * rotationScale;
      const faceModel3x3 = new Amaz.Matrix3x3f();
      Amaz.Matrix3x3f.eulerToMatrix(faceEuler, faceModel3x3);
      const faceModel4x4 = new Amaz.Matrix4x4f(faceModel3x3);
      return faceModel4x4;
    }
    return new Amaz.Matrix4x4f(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
  }
}

exports.FaceMaskControllerSystem = FaceMaskControllerSystem;
