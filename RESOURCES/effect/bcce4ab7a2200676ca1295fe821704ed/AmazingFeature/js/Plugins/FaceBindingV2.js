"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FaceBinding = exports.FaceBindingAnchorType = exports.FaceBindingAlgorithmType = void 0;
const APJS = require('../amazingpro.js')
const { registerClass, serialize, userPublicAPI, userPrivateAPI, hideAPIPrototype, EnterInternalScope, QuitInternalScope, } = APJS;
const MAX_FACE_COUNT = 5;
const ALG_PARA_FACE_FITTING_FOV = 'facefitting_3d_solver_camera_fov';
const ALG_MODEL_MATRIX = 'modelMatrix';
const ALG_MODEL_MATRIX_FACE_CAPTURE = 'model_matrix_face_cap';
const ALG_RESULT_VERTICES_KEY = 'vertexes';
const ALG_RESULT_VERTICES_WITH_EAR_KEY = 'vertexes_head_ear';
const FACEINSET_PARAM_BINDING_TARGET = 'BindingTarget';
const algoManger = effect.Amaz.AmazingManager.getSingleton('Algorithm');
var FaceBindingAlgorithmType;
(function (FaceBindingAlgorithmType) {
    FaceBindingAlgorithmType[FaceBindingAlgorithmType["FaceCapture"] = 1] = "FaceCapture";
    FaceBindingAlgorithmType[FaceBindingAlgorithmType["HeadShape"] = 2] = "HeadShape";
    FaceBindingAlgorithmType[FaceBindingAlgorithmType["FaceShape"] = 4] = "FaceShape";
    FaceBindingAlgorithmType[FaceBindingAlgorithmType["EarShape"] = 8] = "EarShape";
    FaceBindingAlgorithmType[FaceBindingAlgorithmType["HeadEarShape"] = 10] = "HeadEarShape";
})(FaceBindingAlgorithmType = exports.FaceBindingAlgorithmType || (exports.FaceBindingAlgorithmType = {}));
var FaceBindingAnchorType;
(function (FaceBindingAnchorType) {
    FaceBindingAnchorType[FaceBindingAnchorType["FaceCenter"] = 0] = "FaceCenter";
    FaceBindingAnchorType[FaceBindingAnchorType["LeftEye"] = 816] = "LeftEye";
    FaceBindingAnchorType[FaceBindingAnchorType["RightEye"] = 83] = "RightEye";
    FaceBindingAnchorType[FaceBindingAnchorType["Forehead"] = 641] = "Forehead";
    FaceBindingAnchorType[FaceBindingAnchorType["MouthCenter"] = 144] = "MouthCenter";
    FaceBindingAnchorType[FaceBindingAnchorType["Chin"] = 133] = "Chin";
    FaceBindingAnchorType[FaceBindingAnchorType["LeftEarlobe"] = 2233] = "LeftEarlobe";
    FaceBindingAnchorType[FaceBindingAnchorType["RightEarlobe"] = 2049] = "RightEarlobe";
    FaceBindingAnchorType[FaceBindingAnchorType["Custom"] = 9999] = "Custom";
})(FaceBindingAnchorType = exports.FaceBindingAnchorType || (exports.FaceBindingAnchorType = {}));
let FaceBinding = class FaceBinding extends APJS.DynamicComponent {
    constructor(rtti) {
        EnterInternalScope();
        super(rtti);
        this.anchorType = FaceBindingAnchorType.FaceCenter;
        this.customAnchorPoint = new APJS.Vector3f(0, 0, 0);
        this.faceIndex = 0;
        this.graphName = '';
        this.algorithmNode = 'facefitting_3d_0';
        this.algorithmType = FaceBindingAlgorithmType.FaceCapture;
        this.enableCustomBindingInput = false;
        this.customBindingInput = null;
        this.faceFittingFOV = 0.0;
        this.sceneObject = null;
        this.faceTransform = null;
        this.graphNode = null;
        this.renderers = [];
        this.faceMeshInfo = null;
        this.camera = null;
        this.defaultCam = new effect.Amaz.Camera();
        this.isFittingAlgReady = false;
        this.anchorOffset = new APJS.Vector3f(0, 0, 0);
        this.customBindingManager = null;
        this.customBindingResult = null;
        this.faceInsetRenderers = [];
        this.isSupportComponentCache = false;
        this.allSceneObjects = new effect.Amaz.Vector();
        this.supportRendererHide = false;
        this.isNeedResetConcernedComponents = false;
        this.initialLocalMatrix = null;
        this.name = 'FaceBinding';
        this.defaultCam.type = effect.Amaz.CameraType.PERSPECTIVE;
        this.sceneObjectToCamerasMap = new Map();
        this.supportRendererHide = typeof effect.Amaz.Renderer.prototype.hide === 'function';
        QuitInternalScope(this);
    }
    get faceID() {
        return this.faceIndex + 1;
    }
    set faceID(value) {
        if (value < 1 || value > MAX_FACE_COUNT) {
            console.error(`FaceBinding error: faceID must be between 1 and ${MAX_FACE_COUNT}`);
            return;
        }
        this.faceIndex = value - 1;
    }
    onStart() {
        this.sceneObject = this.getSceneObject().getNative();
        this.faceTransform = this.sceneObject.getComponent('Transform');
        if (!this.enableCustomBindingInput) {
            this.graphNode = APJS.AlgorithmManager.getGraphNode(this.graphName, this.algorithmNode);
        }
        this.isSupportComponentCache = this.isVersionLargerThanMinSupportVersion();
        this.isNeedResetConcernedComponents = true;
        if (this.faceTransform) {
            this.initialLocalMatrix = new effect.Amaz.Matrix4x4f();
            this.initialLocalMatrix.copy(this.faceTransform.localMatrix);
        }
    }
    onUpdate(deltaTime) {
        if (this.isNeedResetConcernedComponents) {
            this.resetConcernedComponents();
            this.isNeedResetConcernedComponents = false;
        }
        if (!this.collectRenderers()) {
            return;
        }
        if (!this.checkFittingAlgorithmReady()) {
            return;
        }
        if (!this.findFittingCamera()) {
            return;
        }
        this.setAlgorithmParam();
        this.applyFitting();
    }
    onEvent(event) {
        if (event.type === effect.Amaz.EventType.SCENE_COMPONENTS_ADDED_OR_REMOVED && this.isSupportComponentCache) {
            this.isNeedResetConcernedComponents = true;
        }
    }
    onDestroy() {
        this.resetRenderers();
    }
    onDisable() {
        if (this.faceTransform && this.initialLocalMatrix) {
            this.faceTransform.localMatrix = this.initialLocalMatrix;
        }
        this.resetRenderers();
        this.faceMeshInfo = null;
        this.isFittingAlgReady = false;
    }
    resetConcernedComponents() {
        this.sceneObjectToCamerasMap.clear();
        this.allSceneObjects = this.sceneObject.scene.entities;
        for (let i = 0; i < this.allSceneObjects.size(); ++i) {
            const sceneObj = this.allSceneObjects.get(i);
            const cameras = sceneObj.getComponentsRecursive('Camera');
            this.sceneObjectToCamerasMap.set(sceneObj.handle, cameras);
        }
    }
    isVersionLargerThanMinSupportVersion() {
        const MIN_VERSION = 2020;
        let curVersion = APJS.getEngineVersion();
        curVersion = curVersion.replace(/\./g, '');
        const version = parseInt(curVersion);
        return version >= MIN_VERSION;
    }
    collectRenderers() {
        this.resetRenderers();
        this.renderers = this.getEnabledRenderers(this.sceneObject);
        this.faceInsetRenderers = this.renderers.filter(r => r.isInstanceOf('FaceInsetRenderer'));
        return this.renderers.length > 0;
    }
    getEnabledRenderers(sceneObject) {
        const renderers = [];
        const allRenderers = sceneObject.getComponentsRecursive('Renderer');
        for (let i = 0; i < allRenderers.size(); ++i) {
            const renderer = allRenderers.get(i);
            if (renderer.isInheritedEnabled()) {
                renderers.push(renderer);
            }
        }
        return renderers;
    }
    resetRenderers() {
        for (const renderer of this.renderers) {
            if (!this.supportRendererHide) {
                renderer.enabled = true;
            }
            renderer.useCustomProjectMatrix = false;
        }
        this.renderers.length = 0;
        for (const renderer of this.faceInsetRenderers) {
            renderer.insetParams.remove(FACEINSET_PARAM_BINDING_TARGET);
        }
        this.faceInsetRenderers.length = 0;
    }
    checkFittingAlgorithmReady() {
        const faceFittingCount = this.getFittingCount();
        if (faceFittingCount <= this.faceIndex) {
            this.faceMeshInfo = null;
        }
        else if (faceFittingCount === 1) {
            this.faceMeshInfo = this.getFittingInfo(this.faceIndex);
        }
        else {
            const faces = [];
            const ids = [];
            const idxs = Array.from({ length: faceFittingCount }, (_, i) => i);
            for (let i = 0; i < faceFittingCount; ++i) {
                const info = this.getFittingInfo(i);
                faces.push(info);
                ids.push(info.data.get('face_id'));
            }
            idxs.sort((l, r) => ids[l] - ids[r]);
            this.faceMeshInfo = faces[idxs[this.faceIndex]];
        }
        this.isFittingAlgReady = this.faceMeshInfo !== null;
        if (!this.isFittingAlgReady) {
            for (const renderer of this.renderers) {
                if (this.supportRendererHide) {
                    renderer.hide();
                }
                else {
                    renderer.enabled = false;
                }
            }
        }
        return this.isFittingAlgReady;
    }
    getFittingCount() {
        var _a, _b, _c, _d;
        if (!this.enableCustomBindingInput) {
            return (_b = (_a = this.graphNode) === null || _a === void 0 ? void 0 : _a.getInfoCount(0)) !== null && _b !== void 0 ? _b : 0;
        }
        return (_d = (_c = this.customBindingResult) === null || _c === void 0 ? void 0 : _c.getAlgorithmInfoCount(this.graphName, this.algorithmNode, '', 0)) !== null && _d !== void 0 ? _d : 0;
    }
    getFittingInfo(faceIndex) {
        if (!this.enableCustomBindingInput) {
            return this.graphNode.getInfo('', faceIndex);
        }
        return this.customBindingResult.getAlgorithmInfo(this.graphName, this.algorithmNode, '', faceIndex);
    }
    getVisibleCamera(sceneObject, renderers, useCache) {
        var _a, _b;
        const entities = useCache ? this.allSceneObjects : ((_b = (_a = sceneObject.scene) === null || _a === void 0 ? void 0 : _a.entities) !== null && _b !== void 0 ? _b : null);
        if (!entities) {
            return null;
        }
        for (let i = 0; i < entities.size(); ++i) {
            const entity = entities.get(i);
            const cameras = useCache ? this.sceneObjectToCamerasMap.get(entity.handle) : entity.getComponentsRecursive('Camera');
            if (!cameras || cameras.size() === 0) {
                continue;
            }
            for (let j = 0; j < cameras.size(); ++j) {
                const camera = cameras.get(j);
                if (!camera.entity.visible) {
                    continue;
                }
                for (let k = 0; k < renderers.length; ++k) {
                    const renderer = renderers[k];
                    if (camera.isEntityVisible(renderer.entity)) {
                        return camera;
                    }
                }
            }
        }
        return null;
    }
    calcFaceFittingFOV() {
        const entity = this.getSceneObject().getNative();
        const renderers = this.getEnabledRenderers(entity);
        const camera = this.getVisibleCamera(entity, renderers, false);
        return camera === null ? undefined : this.getFaceFittingFOV(camera);
    }
    getFaceFittingFOV(camera) {
        if (camera.type !== effect.Amaz.CameraType.PERSPECTIVE) {
            return 60.0;
        }
        else {
            if (camera.fovy > 90.0) {
                camera.fovType = effect.Amaz.CameraFovType.CUSTOM;
                camera.fovy = 90.0;
            }
            return camera.fovy;
        }
    }
    findFittingCamera() {
        if (this.algorithmType === FaceBindingAlgorithmType.FaceCapture && this.camera !== null) {
            return true;
        }
        this.camera = this.getVisibleCamera(this.sceneObject, this.renderers, this.isSupportComponentCache);
        return this.camera !== null;
    }
    setAlgorithmParam() {
        var _a;
        const fovy = this.getFaceFittingFOV(this.camera);
        if (fovy > 0 && Math.abs(this.faceFittingFOV - fovy) > 1e-6) {
            if (!this.enableCustomBindingInput) {
                this.graphNode.setFloat(ALG_PARA_FACE_FITTING_FOV, fovy);
            }
            else {
                (_a = this.customBindingManager) === null || _a === void 0 ? void 0 : _a.setAlgorithmParam(this.graphName, this.algorithmNode, 2, ALG_PARA_FACE_FITTING_FOV, fovy);
            }
            this.faceFittingFOV = fovy;
        }
    }
    applyFitting() {
        var _a, _b;
        const modelMatrix = this.faceMeshInfo.data.get(this.algorithmType === FaceBindingAlgorithmType.FaceCapture ?
            ALG_MODEL_MATRIX_FACE_CAPTURE :
            ALG_MODEL_MATRIX);
        const orgModelMatrix = this.enableCustomBindingInput
            ? modelMatrix
            : modelMatrix.getNative();
        (_a = this.faceTransform) === null || _a === void 0 ? void 0 : _a.setWorldMatrix(orgModelMatrix);
        const cameraTransform = this.camera.entity.getComponent('Transform');
        const cameraPos = cameraTransform.getWorldPosition();
        this.anchorOffset = this.getAnchorOffset();
        const translation = new effect.Amaz.Vector4f(this.anchorOffset.x, this.anchorOffset.y, this.anchorOffset.z, 1.0);
        const newOffset = orgModelMatrix.multiplyVector4(translation);
        const newOffsetVec3 = new effect.Amaz.Vector3f(newOffset.x, newOffset.y, newOffset.z);
        newOffsetVec3.add(cameraPos);
        (_b = this.faceTransform) === null || _b === void 0 ? void 0 : _b.setWorldPosition(newOffsetVec3);
        this.handleOrthProjection();
        this.handleFaceInsetRenderers();
    }
    getAnchorOffset() {
        let anchorOffset = this.queryStaticAnchorPoint(this.anchorType);
        if (this.anchorType !== FaceBindingAnchorType.FaceCenter) {
            if (this.algorithmType !== FaceBindingAlgorithmType.FaceCapture) {
                const vertKey = (this.algorithmType & FaceBindingAlgorithmType.EarShape) === 0 ?
                    ALG_RESULT_VERTICES_KEY : ALG_RESULT_VERTICES_WITH_EAR_KEY;
                if (this.enableCustomBindingInput) {
                    const vertices = this.faceMeshInfo.get(vertKey);
                    if (this.anchorType < vertices.size()) {
                        anchorOffset = new APJS.Vector3f(vertices.get(this.anchorType));
                    }
                }
                else {
                    const vertices = this.faceMeshInfo.get(vertKey);
                    if ((this.anchorType + 1) * 3 <= vertices.length) {
                        anchorOffset = new APJS.Vector3f(vertices[3 * this.anchorType], vertices[3 * this.anchorType + 1], vertices[3 * this.anchorType + 2]);
                    }
                }
            }
        }
        return anchorOffset;
    }
    queryStaticAnchorPoint(anchorType) {
        switch (anchorType) {
            case FaceBindingAnchorType.LeftEye:
                return new APJS.Vector3f(-2.965, 1.806, 4.024);
            case FaceBindingAnchorType.RightEye:
                return new APJS.Vector3f(2.959, 1.801, 4.02);
            case FaceBindingAnchorType.Forehead:
                return new APJS.Vector3f(0, 9.74, 3.468);
            case FaceBindingAnchorType.MouthCenter:
                return new APJS.Vector3f(0, -3.978, 5.621);
            case FaceBindingAnchorType.Chin:
                return new APJS.Vector3f(0, -7.581, 5.6);
            case FaceBindingAnchorType.LeftEarlobe:
                return new APJS.Vector3f(-7.208, -1.843, -4.141);
            case FaceBindingAnchorType.RightEarlobe:
                return new APJS.Vector3f(7.208, -1.843, -4.141);
            case FaceBindingAnchorType.Custom:
                return this.customAnchorPoint;
            case FaceBindingAnchorType.FaceCenter:
            default:
                return new APJS.Vector3f(0, 0, 0);
        }
    }
    handleOrthProjection() {
        if (this.camera.type === effect.Amaz.CameraType.PERSPECTIVE) {
            return;
        }
        this.prepareDefaultCamera();
        const projMat = this.defaultCam.projectionMatrix;
        for (const renderer of this.renderers) {
            if (this.camera.isEntityVisible(renderer.entity)) {
                renderer.useCustomProjectMatrix = true;
                renderer.customProjectMatrix = projMat;
            }
        }
        this.resetDefaultCamera();
    }
    handleFaceInsetRenderers() {
        for (const renderer of this.faceInsetRenderers) {
            const faceInsetRenderer = renderer;
            faceInsetRenderer.insetParams.set(FACEINSET_PARAM_BINDING_TARGET, this.faceTransform);
        }
    }
    prepareDefaultCamera() {
        if (this.camera.type !== effect.Amaz.CameraType.PERSPECTIVE) {
            this.defaultCam.zNear = this.camera.zNear;
            this.defaultCam.zFar = this.camera.zFar;
            this.defaultCam.fovy = 60.0;
            this.defaultCam.renderTexture = this.camera.renderTexture;
        }
    }
    resetDefaultCamera() {
        this.defaultCam.renderTexture = null;
    }
};
__decorate([
    serialize,
    userPublicAPI()
], FaceBinding.prototype, "anchorType", void 0);
__decorate([
    serialize,
    userPublicAPI()
], FaceBinding.prototype, "customAnchorPoint", void 0);
__decorate([
    serialize
], FaceBinding.prototype, "faceIndex", void 0);
__decorate([
    serialize
], FaceBinding.prototype, "graphName", void 0);
__decorate([
    serialize
], FaceBinding.prototype, "algorithmNode", void 0);
__decorate([
    serialize
], FaceBinding.prototype, "algorithmType", void 0);
__decorate([
    serialize
], FaceBinding.prototype, "enableCustomBindingInput", void 0);
__decorate([
    serialize
], FaceBinding.prototype, "customBindingInput", void 0);
__decorate([
    serialize
], FaceBinding.prototype, "faceFittingFOV", void 0);
__decorate([
    userPublicAPI()
], FaceBinding.prototype, "faceID", null);
__decorate([
    userPrivateAPI()
], FaceBinding.prototype, "calcFaceFittingFOV", null);
__decorate([
    userPrivateAPI()
], FaceBinding.prototype, "queryStaticAnchorPoint", null);
FaceBinding = __decorate([
    registerClass()
], FaceBinding);
exports.FaceBinding = FaceBinding;
hideAPIPrototype(FaceBinding);
