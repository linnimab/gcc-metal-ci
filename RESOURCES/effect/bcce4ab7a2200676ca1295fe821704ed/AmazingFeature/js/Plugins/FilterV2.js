"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FilterV2 = void 0;
const APJS = require('../amazingpro.js')
const { registerClass, serialize } = APJS;
const Amaz = effect.Amaz;
let FilterV2 = class FilterV2 extends APJS.DynamicComponent {
    constructor(rtti) {
        super(rtti);
        this.lutEnabled = true;
        this.lutTexture = null;
        this.intensity = 1.0;
        this.colorCorrEnabled = false;
        this.exposure = 0.0;
        this.contrast = 0.0;
        this.brightness = 0.0;
        this.saturation = 0.0;
        this.temperature = 0.0;
        this.tint = 0.0;
        this.material = null;
        this.missingLut = false;
        this._initState = false;
        this._camera = null;
        this._scene = null;
        this._material = null;
        this._commandBuffer = null;
        this._renderTexture = null;
        this._blitMesh = null;
        this._propertyBlock = null;
        this.name = 'FilterV2';
    }
    onStart() {
        this._initState = false;
    }
    lazyInit() {
        const entity = this.getSceneObject().getNative();
        this._scene = entity.scene;
        this._blitMesh = this.createTriangleMesh();
        const selfCamera = entity.getComponent('Camera');
        if (selfCamera !== null && selfCamera.renderTexture !== null) {
            this._camera = selfCamera;
        }
        else {
            const nodeEntity = this.getEffectNode(entity);
            const nodeCamera = this.getCameraForEntity(entity, nodeEntity);
            if (nodeCamera !== null && nodeCamera.renderTexture !== null) {
                this._camera = nodeCamera;
            }
        }
        if (this._camera !== null) {
            Amaz.AmazingManager.addListener(this._camera, effect.Amaz.CameraEvent.RENDER_IMAGE_EFFECTS, this.renderFilter, this);
        }
        else {
            Amaz.LOGE(this.name, 'lazyInit fail, camera not found with entity: ' + entity.name);
        }
    }
    getEffectNode(entity) {
        let parentTrans = entity.getComponent('Transform');
        while (parentTrans && parentTrans.parent) {
            parentTrans = parentTrans.parent;
        }
        return parentTrans.entity;
    }
    getCameraForEntity(entity, root) {
        if (!entity || !root) {
            return null;
        }
        const cameras = root.getComponentsRecursive('Camera');
        for (let j = 0; j < cameras.size(); j++) {
            const camera = cameras.get(j);
            if (camera.isEntityVisible(entity)) {
                return camera;
            }
        }
        return null;
    }
    onUpdate(deltaTime) {
        if (!this._initState) {
            this._initState = true;
            this.lazyInit();
        }
        this.updateUniforms();
    }
    onDestroy() {
        if (this._camera !== null) {
            Amaz.AmazingManager.removeListener(this._camera, effect.Amaz.CameraEvent.RENDER_IMAGE_EFFECTS, this.renderFilter, this);
            this._camera = null;
        }
        this._scene = null;
        this._material = null;
        this._commandBuffer = null;
        this._renderTexture = null;
        this._blitMesh = null;
        this._propertyBlock = null;
    }
    updateUniforms() {
        var _a;
        this._propertyBlock = (_a = this._propertyBlock) !== null && _a !== void 0 ? _a : new effect.Amaz.MaterialPropertyBlock();
        if (this.lutEnabled) {
            this._propertyBlock.setFloat('_Intensity', this.intensity);
            this._propertyBlock.setTexture('_LutTexture', this.lutTexture.getNative());
        }
        if (this.colorCorrEnabled) {
            this._propertyBlock.setFloat('_Exposure', this.exposure * 3.0);
            this._propertyBlock.setFloat('_Contrast', this.contrast);
            this._propertyBlock.setFloat('_Brightness', this.brightness);
            this._propertyBlock.setFloat('_Saturation', this.saturation);
            this._propertyBlock.setFloat('_Temperature', this.temperature);
            this._propertyBlock.setFloat('_Tint', this.tint);
        }
    }
    setUpCommands(material, rt) {
        var _a;
        if (!this._commandBuffer || this._material !== material || !this._renderTexture || !this._renderTexture.equals(rt)) {
            this._material = material;
            this._renderTexture = rt;
            this._commandBuffer = (_a = this._commandBuffer) !== null && _a !== void 0 ? _a : new effect.Amaz.CommandBuffer();
            this._commandBuffer.clearAll();
            this._commandBuffer.setRenderTexture(rt);
            this._commandBuffer.drawMesh(this._blitMesh, new effect.Amaz.Matrix4x4f(), material.getNative(), 0, 0, this._propertyBlock, true);
        }
    }
    renderFilter(comp, camera, eventType) {
        if (camera.enabled && comp.isInheritedEnabled() && eventType == effect.Amaz.CameraEvent.RENDER_IMAGE_EFFECTS) {
            if (comp.material && (comp.isLutValid() || comp.isColorCoorValid())) {
                comp.setUpCommands(comp.material, camera.renderTexture);
                comp._scene.commitCommandBuffer(comp._commandBuffer);
            }
        }
    }
    isLutValid() {
        return this.lutEnabled && !this.missingLut && this.intensity !== 0;
    }
    isColorCoorValid() {
        var isParamNotZero = (this.exposure !== 0 || this.contrast !== 0 || this.brightness !== 0 || this.saturation !== 0 || this.temperature !== 0 || this.tint !== 0);
        return this.colorCorrEnabled && !(this.lutEnabled && this.missingLut) && isParamNotZero;
    }
    createTriangleMesh() {
        var mesh = new effect.Amaz.Mesh();
        var pos = new effect.Amaz.VertexAttribDesc();
        pos.semantic = effect.Amaz.VertexAttribType.POSITION;
        var uv = new effect.Amaz.VertexAttribDesc();
        uv.semantic = effect.Amaz.VertexAttribType.TEXCOORD0;
        var attribs = new effect.Amaz.Vector();
        attribs.pushBack(pos);
        attribs.pushBack(uv);
        mesh.vertexAttribs = attribs;
        const vertexData = [
            1.0,
            1.0,
            0.0,
            1.0,
            1.0,
            1.0,
            -1.0,
            0.0,
            1.0,
            0.0,
            -1.0,
            -1.0,
            0.0,
            0.0,
            0.0,
            -1.0,
            1.0,
            0.0,
            0.0,
            1.0,
        ];
        var fv = new effect.Amaz.FloatVector();
        for (var i = 0; i < vertexData.length; i++) {
            fv.pushBack(vertexData[i]);
        }
        mesh.vertices = fv;
        var submesh = new effect.Amaz.SubMesh();
        submesh.primitive = effect.Amaz.Primitive.TRIANGLES;
        const indexData = [3, 2, 1, 1, 0, 3];
        const indices = new effect.Amaz.UInt16Vector();
        for (var i = 0; i < indexData.length; i++) {
            indices.pushBack(indexData[i]);
        }
        submesh.indices16 = indices;
        submesh.mesh = mesh;
        mesh.addSubMesh(submesh);
        return mesh;
    }
};
__decorate([
    serialize
], FilterV2.prototype, "lutEnabled", void 0);
__decorate([
    serialize
], FilterV2.prototype, "lutTexture", void 0);
__decorate([
    serialize
], FilterV2.prototype, "intensity", void 0);
__decorate([
    serialize
], FilterV2.prototype, "colorCorrEnabled", void 0);
__decorate([
    serialize
], FilterV2.prototype, "exposure", void 0);
__decorate([
    serialize
], FilterV2.prototype, "contrast", void 0);
__decorate([
    serialize
], FilterV2.prototype, "brightness", void 0);
__decorate([
    serialize
], FilterV2.prototype, "saturation", void 0);
__decorate([
    serialize
], FilterV2.prototype, "temperature", void 0);
__decorate([
    serialize
], FilterV2.prototype, "tint", void 0);
__decorate([
    serialize
], FilterV2.prototype, "material", void 0);
FilterV2 = __decorate([
    registerClass()
], FilterV2);
exports.FilterV2 = FilterV2;
