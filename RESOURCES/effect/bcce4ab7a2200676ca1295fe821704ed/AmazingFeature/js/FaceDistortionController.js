const Amaz = effect.Amaz;

class FaceDistortionController {
  constructor() {
    this.name = 'FaceDistortionController';

    this.faceReshapeMeshRender = null;
    this.faceReshapeComponent = null;
    this.bInit = false;
  }

  onStart() {
    console.log('running:FaceDistortionController:onStart');

    this.faceReshapeMeshRender = this.entity.addComponent('MeshRenderer');
    this.faceReshapeMeshRender.sharedMaterial = this.Material;
    this.faceReshapeMeshRender.autoSortingOrder = this.autoSortingOrder;
    this.faceReshapeMeshRender.sortingOrder = this.sortingOrder;

    this.faceReshapeComponent = new Amaz.FaceReshape();
    this.faceReshapeComponent.faceids = this.faceids;
    this.faceReshapeComponent.params.params = this.params;
    this.faceReshapeComponent.params.indices = this.indices;

    this.faceReshapeComponent.params.degrees.clear();
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_eye_far * this.factor); //0
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_eye_zoom * this.factor); //1
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_eye_rotate * this.factor); //2
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_eye_move * this.factor); //3
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_nose_zoom * this.factor); //4
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_nose_move * this.factor); //5
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_lips_move * this.factor); //6
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_lips_zoom * this.factor); //7
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_face_chinmove * this.factor); //8
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_face_forehad * this.factor); //9
    this.faceReshapeComponent.params.degrees.pushBack(0.0); //10
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_face_zoom * this.factor); //11
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_face_small * this.factor); //12
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_face_jawbonezoom * this.factor); //13
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_face_cheekbonezoom * this.factor); //14
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_lips_smlie * this.factor); //15
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_eye_eyecorner * this.factor); //16
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_lips_enhance * this.factor); //17
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_face_chinpointy * this.factor); //18
    this.faceReshapeComponent.params.degrees.pushBack(0.0); //19
    this.faceReshapeComponent.params.degrees.pushBack(2); //20
    this.faceReshapeComponent.params.degrees.pushBack(0.0); //21
    this.faceReshapeComponent.params.degrees.pushBack(this.facedistortion_eye_eyebrowjump * this.factor); //22

    const comps = new Amaz.Vector();
    comps.pushBack(this.faceReshapeComponent);
    this.entity.components = comps;

    this.bInit = true;
  }

  onUpdate(deltaTime) {
    if (
      !this.bInit ||
      this.faceReshapeMeshRender === null ||
      this.faceReshapeMeshRender === undefined ||
      this.faceReshapeComponent === null ||
      this.faceReshapeComponent === undefined
    ) {
      return;
    }

    this.faceReshapeMeshRender.autoSortingOrder = this.autoSortingOrder;
    this.faceReshapeMeshRender.sortingOrder = this.sortingOrder;

    this.faceReshapeComponent.faceids = this.faceids;

    this.faceReshapeComponent.params.degrees.set(0, this.facedistortion_eye_far * this.factor); //0
    this.faceReshapeComponent.params.degrees.set(1, this.facedistortion_eye_zoom * this.factor); //1
    this.faceReshapeComponent.params.degrees.set(2, this.facedistortion_eye_rotate * this.factor); //2
    this.faceReshapeComponent.params.degrees.set(3, this.facedistortion_eye_move * this.factor); //3
    this.faceReshapeComponent.params.degrees.set(4, this.facedistortion_nose_zoom * this.factor); //4
    this.faceReshapeComponent.params.degrees.set(5, this.facedistortion_nose_move * this.factor); //5
    this.faceReshapeComponent.params.degrees.set(6, this.facedistortion_lips_move * this.factor); //6
    this.faceReshapeComponent.params.degrees.set(7, this.facedistortion_lips_zoom * this.factor); //7
    this.faceReshapeComponent.params.degrees.set(8, this.facedistortion_face_chinmove * this.factor); //8
    this.faceReshapeComponent.params.degrees.set(9, this.facedistortion_face_forehad * this.factor); //9
    this.faceReshapeComponent.params.degrees.set(11, this.facedistortion_face_zoom * this.factor); //11
    this.faceReshapeComponent.params.degrees.set(12, this.facedistortion_face_small * this.factor); //12
    this.faceReshapeComponent.params.degrees.set(13, this.facedistortion_face_jawbonezoom * this.factor); //13
    this.faceReshapeComponent.params.degrees.set(14, this.facedistortion_face_cheekbonezoom * this.factor); //14
    this.faceReshapeComponent.params.degrees.set(15, this.facedistortion_lips_smlie * this.factor); //15
    this.faceReshapeComponent.params.degrees.set(16, this.facedistortion_eye_eyecorner * this.factor); //16
    this.faceReshapeComponent.params.degrees.set(17, this.facedistortion_lips_enhance * this.factor); //17
    this.faceReshapeComponent.params.degrees.set(18, this.facedistortion_face_chinpointy * this.factor); //18
    this.faceReshapeComponent.params.degrees.set(22, this.facedistortion_eye_eyebrowjump * this.factor); //22
  }

  onEnable() {
    if (
      this.bInit &&
      this.faceReshapeMeshRender !== null &&
      this.faceReshapeMeshRender !== undefined &&
      this.faceReshapeComponent !== null &&
      this.faceReshapeComponent !== undefined
    ) {
      this.faceReshapeMeshRender.enabled = true;
      this.faceReshapeComponent.enabled = true;
    }
    console.log('[OnEnable]', this.name);
  }

  onDisable() {
    if (
      this.bInit &&
      this.faceReshapeMeshRender !== null &&
      this.faceReshapeMeshRender !== undefined &&
      this.faceReshapeComponent !== null &&
      this.faceReshapeComponent !== undefined
    ) {
      this.faceReshapeMeshRender.enabled = false;
      this.faceReshapeComponent.enabled = false;
    }
    console.log('[onDisable]', this.name);
  }

  clean() {
    // clean before save
    if (this.bInit && this.faceReshapeComponent !== null && this.faceReshapeComponent !== undefined) {
      this.entity.removeComponent(this.faceReshapeComponent);
    }

    if (this.bInit && this.faceReshapeMeshRender !== null && this.faceReshapeMeshRender !== undefined) {
      this.entity.removeComponent(this.faceReshapeMeshRender);
    }
  }
  beforeEditorSave() {
    this.clean();
  }

  onDestroy() {
    this.clean();
  }
}

exports.FaceDistortionController = FaceDistortionController;
