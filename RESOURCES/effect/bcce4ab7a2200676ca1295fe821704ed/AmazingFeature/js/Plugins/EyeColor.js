"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.EyeColor = exports.EyeApplyingScope = void 0;
const APJS = require('../amazingpro.js')
const { registerClass, serialize, userPublicAPI } = APJS;
const Amaz = effect.Amaz;
var EyeApplyingScope;
(function (EyeApplyingScope) {
    EyeApplyingScope[EyeApplyingScope["BothEyes"] = 0] = "BothEyes";
    EyeApplyingScope[EyeApplyingScope["LeftEyeOnly"] = 1] = "LeftEyeOnly";
    EyeApplyingScope[EyeApplyingScope["RightEyeOnly"] = 2] = "RightEyeOnly";
})(EyeApplyingScope = exports.EyeApplyingScope || (exports.EyeApplyingScope = {}));
let EyeColor = class EyeColor extends APJS.DynamicComponent {
    constructor(rtti) {
        super(rtti);
        this.intensity = 0.0;
        this.faceIndexes = [];
        this.makeupTexture = null;
        this.blendMode = 0.0;
        this.isOpacityEnabled = false;
        this.opacityTexture = null;
        this.color = new APJS.Color(1, 1, 1, 1);
        this.isReflectionEnabled = false;
        this.reflectionTexture = null;
        this.reflectionIntensity = 0.0;
        this.reflectionBlendMode = 0.0;
        this.applyingScope = EyeApplyingScope.BothEyes;
        this.maskTexture = null;
        this.useSegmentation = false;
        this.templateMesh = null;
        this.templateMaterial = null;
        this.templateMaskMesh = null;
        this.templateMaskMaterial = null;
        this._initState = false;
        this._propDirty = true;
        this._makeupComp = null;
        this._makeupRenderer = null;
        this._maskRenderer = null;
        this._renderTexture = null;
        this._mainMaterial = null;
        this.name = 'EyeColor';
    }
    onEnable() {
        this.updateComponentStatus(true);
    }
    onDisable() {
        this.updateComponentStatus(false);
    }
    onStart() {
        this._initState = false;
    }
    onUpdate(deltaTime) {
        if (!this._initState) {
            this.initComponents();
            this.updateComponentStatus(this.enabled);
        }
        if (this._initState) {
            this.updateMaterialProperties();
        }
    }
    beforeEditorSave() {
        this.removeComponents();
    }
    onRelease() {
        this.removeComponents();
    }
    onDestroy() {
    }
    initComponents() {
        var _a, _b;
        const makeupSceneObject = this.getSceneObject();
        const makeupEntity = this.getSceneObject().getNative();
        this._makeupRenderer = makeupEntity.getComponent('MeshRenderer');
        if (!this._makeupRenderer) {
            return;
        }
        this._makeupComp = makeupSceneObject.getComponent('FaceMakeupIris');
        if (!this._makeupComp) {
            if (!this.templateMesh ||
                !this.templateMaterial ||
                !this.templateMaskMesh ||
                !this.templateMaskMaterial) {
                return;
            }
            this._makeupComp = new APJS.FaceMakeupIris();
            this._makeupComp.makeupSceneObject = makeupSceneObject;
            this._makeupComp.makeupType = APJS.MakeupType.Irises;
            this._makeupComp.faceIndexes = this.faceIndexes;
            this._makeupComp.templateMesh = this.templateMesh;
            this._makeupComp.templateMaterials = [this.templateMaterial];
            this._makeupComp.templateMaskMesh = this.templateMaskMesh;
            this._makeupComp.templateMaskMaterials = [this.templateMaskMaterial];
            this._makeupRenderer.mesh = this.templateMesh.getNative();
            this._makeupRenderer.entirePingPong = true;
            const components = new Amaz.Vector();
            components.pushBack(this._makeupComp.getNative());
            makeupEntity.components = components;
            const maskSceneObject = makeupSceneObject.scene.createSceneObject('EyeColorMask');
            const maskEntity = maskSceneObject.getNative();
            maskSceneObject.layer = makeupSceneObject.layer;
            const makeupTrans = makeupEntity.getComponent('Transform');
            const maskTrans = maskEntity.getComponent('Transform');
            makeupTrans.addTransform(maskTrans);
            this._makeupComp.maskSceneObject = maskSceneObject;
            this._maskRenderer = maskEntity.addComponent('MeshRenderer');
            this._maskRenderer.entirePingPong = true;
            this._maskRenderer.sortingOrder = this._makeupRenderer.sortingOrder;
            this._maskRenderer.mesh = this.templateMaskMesh.getNative();
            this._maskRenderer.sharedMaterial = this.templateMaskMaterial.getNative();
            this._mainMaterial = APJS.transferToAPJSObj(this._maskRenderer.sharedMaterial);
            this._mainMaterial.setMatrix('uSTMatrix', new APJS.Matrix4x4f(2.2222222222222223, 0.0, 0.0, 0.0, 0.0, 4.3478260869565215, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, -0.6111111111111112, -1.9130434782608696, 0.0, 1.0));
        }
        else {
            const maskSceneObject = this._makeupComp.maskSceneObject;
            if (!maskSceneObject) {
                return;
            }
            this._maskRenderer = maskSceneObject
                .getNative()
                .getComponent('MeshRenderer');
            this._maskRenderer.sortingOrder = this._makeupRenderer.sortingOrder;
            this._mainMaterial = APJS.transferToAPJSObj(this._maskRenderer.sharedMaterial);
        }
        this._makeupComp.useSegmentation = this.useSegmentation;
        this._makeupComp.onInit();
        this._renderTexture =
            (_b = APJS.transferToAPJSObj((_a = this.getRenderCamera()) === null || _a === void 0 ? void 0 : _a.renderTexture)) !== null && _b !== void 0 ? _b : null;
        this._initState = true;
    }
    updateComponentStatus(enabled) {
        if (this._makeupComp && this._makeupRenderer && this._maskRenderer) {
            this._makeupComp.enabled = enabled;
            this._makeupRenderer.enabled = enabled;
            this._maskRenderer.enabled = enabled;
        }
    }
    removeComponents() {
        if (this._makeupComp) {
            this.getSceneObject().removeComponent(this._makeupComp);
            this._makeupComp = null;
        }
        if (this._makeupRenderer) {
            this._makeupRenderer.enabled = false;
        }
        if (this._maskRenderer) {
            const maskEntity = this._maskRenderer.entity;
            this.getSceneObject().getNative().scene.removeEntity(maskEntity);
            this._maskRenderer = null;
        }
    }
    getEffectNode(entity) {
        let parentTrans = entity.getComponent('Transform');
        while (parentTrans && parentTrans.parent) {
            parentTrans = parentTrans.parent;
        }
        return parentTrans.entity;
    }
    getCameraForEntity(entity) {
        if (!entity) {
            return null;
        }
        const layer = entity.layer;
        const cameras = entity.getComponentsRecursive('Camera');
        for (let j = 0; j < cameras.size(); j++) {
            const camera = cameras.get(j);
            if (camera.layerVisibleMask.test(layer)) {
                return camera;
            }
        }
        return null;
    }
    getRenderCamera() {
        const myEntity = this.getSceneObject().getNative();
        const nodeEntity = this.getEffectNode(myEntity);
        if (nodeEntity) {
            return this.getCameraForEntity(nodeEntity);
        }
        const objects = myEntity.scene.entities;
        for (let i = 0; i < objects.size(); i++) {
            const entity = objects.get(i);
            const camera = this.getCameraForEntity(entity);
            if (camera) {
                return camera;
            }
        }
        return null;
    }
    updateMaterialProperties() {
        if (!this._makeupComp ||
            !this._makeupRenderer ||
            !this._maskRenderer ||
            !this._mainMaterial) {
            return;
        }
        const color = this.color;
        const propertyMap = {
            _Intensity: this.intensity,
            _BaseColor: new APJS.Vector4f(color.r, color.g, color.b, color.a),
            _ReflectionIntensity: this.reflectionIntensity,
            _EnableReflection: this.isReflectionEnabled ? 1 : 0,
            _EnableOpacity: this.isOpacityEnabled ? 1 : 0,
            _InputTexture: this._renderTexture,
            _BaseTexture: this.makeupTexture,
            _OpacityTexture: this.opacityTexture,
            _ReflectionTexture: this.reflectionTexture,
        };
        for (const key in propertyMap) {
            const value = propertyMap[key];
            if (value !== null) {
                this._makeupComp.setMaterialProperty(key, value);
            }
        }
        const maskMaterial = this._mainMaterial;
        if (maskMaterial) {
            maskMaterial.setFloat('_MaskMinCoord', this.applyingScope === EyeApplyingScope.RightEyeOnly ? 0.5 : 0);
            maskMaterial.setFloat('_MaskMaxCoord', this.applyingScope === EyeApplyingScope.LeftEyeOnly ? 0.5 : 1);
            if (this.maskTexture) {
                maskMaterial.setTexture('_MaskTexture', this.maskTexture);
            }
        }
    }
};
__decorate([
    userPublicAPI(),
    serialize
], EyeColor.prototype, "intensity", void 0);
__decorate([
    serialize
], EyeColor.prototype, "faceIndexes", void 0);
__decorate([
    userPublicAPI(),
    serialize
], EyeColor.prototype, "makeupTexture", void 0);
__decorate([
    serialize
], EyeColor.prototype, "blendMode", void 0);
__decorate([
    userPublicAPI(),
    serialize
], EyeColor.prototype, "isOpacityEnabled", void 0);
__decorate([
    userPublicAPI(),
    serialize
], EyeColor.prototype, "opacityTexture", void 0);
__decorate([
    userPublicAPI(),
    serialize
], EyeColor.prototype, "color", void 0);
__decorate([
    userPublicAPI(),
    serialize
], EyeColor.prototype, "isReflectionEnabled", void 0);
__decorate([
    userPublicAPI(),
    serialize
], EyeColor.prototype, "reflectionTexture", void 0);
__decorate([
    userPublicAPI(),
    serialize
], EyeColor.prototype, "reflectionIntensity", void 0);
__decorate([
    serialize
], EyeColor.prototype, "reflectionBlendMode", void 0);
__decorate([
    userPublicAPI(),
    serialize
], EyeColor.prototype, "applyingScope", void 0);
__decorate([
    serialize
], EyeColor.prototype, "maskTexture", void 0);
__decorate([
    serialize
], EyeColor.prototype, "useSegmentation", void 0);
__decorate([
    serialize
], EyeColor.prototype, "templateMesh", void 0);
__decorate([
    serialize
], EyeColor.prototype, "templateMaterial", void 0);
__decorate([
    serialize
], EyeColor.prototype, "templateMaskMesh", void 0);
__decorate([
    serialize
], EyeColor.prototype, "templateMaskMaterial", void 0);
EyeColor = __decorate([
    registerClass()
], EyeColor);
exports.EyeColor = EyeColor;
