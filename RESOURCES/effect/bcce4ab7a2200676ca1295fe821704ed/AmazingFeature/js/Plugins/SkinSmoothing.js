"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FaceRetouch = void 0;
const APJS = require('../amazingpro.js')
const { registerClass, serialize, userPublicAPI, hideAPIPrototype, EnterInternalScope, QuitInternalScope, } = APJS;
const MAX_FACE_COUNT = 5;
const algorithmManager = effect.Amaz.AmazingManager.getSingleton('Algorithm');
let FaceRetouch = class FaceRetouch extends APJS.DynamicComponent {
    constructor(rtti) {
        EnterInternalScope();
        super(rtti);
        this.skinTextureIntensity = 0.5;
        this.eyeBrillianceIntensity = 0.5;
        this.darkCirclesIntensity = 0.5;
        this.smileLinesIntensity = 0.5;
        this.faceIndexes = [0, 1, 2, 3, 4];
        this.graphName = '';
        this.algorithmNode = 'face_0';
        this.faceMaskMaterial = null;
        this.blitMaterial = null;
        this.blurXMaterial = null;
        this.blurYMaterial = null;
        this.blurInnerMaterial = null;
        this.blurOuterMaterial = null;
        this.blendMaterial = null;
        this.smoothMaterial = null;
        this.outputRenderTexture = null;
        this.brightenTexture = null;
        this.faceMaskTexture = null;
        this.faceMesh = null;
        this.entity = null;
        this.faceMaskCamera = null;
        this.identityMatrix = new effect.Amaz.Matrix4x4f();
        this.tempMatPropertyBlock = new effect.Amaz.MaterialPropertyBlock();
        this.isFirstFrameUpdate = true;
        this.faceMaskMatInstance = null;
        this.blitMatInstance = null;
        this.blurXMatInstance = null;
        this.blurYMatInstance = null;
        this.blendMatInstance = null;
        this.blurInnerMatInstance = null;
        this.blurOuterMatInstance = null;
        this.smoothMatInstance = null;
        this.renderTexture = null;
        this.inputRT = null;
        this.faceMaskRT = null;
        this.blendRT = null;
        this.blurXRT = null;
        this.blurYRT = null;
        this.meshTool = new effect.Amaz.AMGFaceMeshUtils();
        this.meshType = effect.Amaz.AMGBeautyMeshType.FACE145;
        this.validFaceCount = 0;
        this.usingCustomRenderTexture = false;
        this.componentMesh = null;
        this.smoothCommandBuffer = null;
        this.blitCommandBuffer = null;
        this.width = -1;
        this.height = -1;
        this.widthDownsample = 324;
        this.heightDownsample = 576;
        this.widthOffset = 0;
        this.heightOffset = 0;
        this.widthDownsampleOffset = 0;
        this.heightDownsampleOffset = 0;
        this.indicesCount = 768;
        this.blitFlag = false;
        this.name = 'FaceRetouch';
        this.identityMatrix.setIdentity();
        QuitInternalScope(this);
    }
    get faceIDs() {
        return this.faceIndexes.map(index => index + 1);
    }
    set faceIDs(value) {
        if (value.some(id => id < 1 || id > MAX_FACE_COUNT)) {
            console.error(`FaceRetouch error: faceID must be between 1 and ${MAX_FACE_COUNT}`);
            return;
        }
        this.faceIndexes = value.map(id => id - 1);
    }
    set subGraphName(value) {
        this.graphName = value;
    }
    onStart() {
        this.entity = this.getSceneObject().getNative();
        if (this.faceMaskMaterial) {
            this.faceMaskMatInstance = this.faceMaskMaterial.instantiate();
        }
        if (this.blitMaterial) {
            this.blitMatInstance = this.blitMaterial.instantiate();
        }
        if (this.blurXMaterial) {
            this.blurXMatInstance = this.blurXMaterial.instantiate();
        }
        if (this.blurYMaterial) {
            this.blurYMatInstance = this.blurYMaterial.instantiate();
        }
        if (this.blurInnerMaterial) {
            this.blurInnerMatInstance = this.blurInnerMaterial.instantiate();
        }
        if (this.blurOuterMaterial) {
            this.blurOuterMatInstance = this.blurOuterMaterial.instantiate();
        }
        if (this.blendMaterial) {
            this.blendMatInstance = this.blendMaterial.instantiate();
        }
        if (this.smoothMaterial) {
            this.smoothMatInstance = this.smoothMaterial.instantiate();
        }
        if (!this.faceMesh) {
            console.error('faceMesh not available');
            return;
        }
        this.componentMesh = this.faceMesh.clone();
        this.componentMesh.name = this.faceMesh.name + '_' + Math.random().toString(36).substring(2, 9);
        this.meshTool.setMesh(this.componentMesh.getNative(), this.meshType, 0, 2);
        if (this.smoothMatInstance) {
            this.smoothMatInstance.setFloat('useSkinTex', 0.0);
        }
        this.renderTexture = this.outputRenderTexture.getNative();
        this.setupRenderTextures();
        this.setupCommandBuffers();
    }
    setupRenderTextures() {
        this.renderTexture.width = this.width;
        this.renderTexture.height = this.height;
        if (this.renderTexture instanceof effect.Amaz.SceneOutputRT) {
            this.inputRT = this.renderTexture;
        }
        else {
            this.inputRT = this.createRenderTexture('inputRT', this.renderTexture.width, this.renderTexture.height, effect.Amaz.PixelFormat.RGBA8Unorm);
            this.blitFlag = true;
        }
        this.faceMaskRT = this.createRenderTexture('faceMaskRT', this.widthDownsample, this.heightDownsample, effect.Amaz.PixelFormat.RGBA8Unorm);
        this.blurXRT = this.createRenderTexture('blurXRT', this.widthDownsample, this.heightDownsample, effect.Amaz.PixelFormat.RGBA8Unorm);
        this.blurYRT = this.createRenderTexture('blurYRT', this.widthDownsample, this.heightDownsample, effect.Amaz.PixelFormat.RGBA8Unorm);
        this.blendRT = this.createRenderTexture('blendRT', this.width, this.height, effect.Amaz.PixelFormat.RGBA8Unorm);
    }
    createRenderTexture(name, width, height, format) {
        const rt = new effect.Amaz.RenderTexture();
        rt.width = Math.floor(width);
        rt.height = Math.floor(height);
        rt.colorFormat = format;
        rt.name = name;
        rt.builtinType = effect.Amaz.BuiltInTextureType.NORAML;
        rt.internalFormat = effect.Amaz.InternalFormat.RGBA8;
        rt.dataType = effect.Amaz.DataType.U8norm;
        rt.depth = 1;
        rt.attachment = effect.Amaz.RenderTextureAttachment.DEPTH24;
        rt.filterMag = effect.Amaz.FilterMode.LINEAR;
        rt.filterMin = effect.Amaz.FilterMode.LINEAR;
        rt.filterMipmap = effect.Amaz.FilterMipmapMode.NONE;
        rt.colorFormat = format || effect.Amaz.PixelFormat.RGBA8Unorm;
        return rt;
    }
    setupCommandBuffers() {
        this.smoothCommandBuffer = new effect.Amaz.CommandBuffer();
        this.blitCommandBuffer = new effect.Amaz.CommandBuffer();
    }
    rebuildCommandBuffers() {
        if (this.smoothCommandBuffer) {
            this.smoothCommandBuffer.clearAll();
        }
        if (this.blitCommandBuffer) {
            this.blitCommandBuffer.clearAll();
        }
        this.setupAllRenderCommands();
    }
    setupAllRenderCommands() {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y, _z, _0, _1, _2, _3, _4;
        if (!this.smoothCommandBuffer || !this.blitCommandBuffer) {
            return;
        }
        if (this.blitFlag) {
            this.smoothCommandBuffer.blit(this.renderTexture, this.inputRT);
            this.blitCommandBuffer.blit(this.renderTexture, this.inputRT);
        }
        this.smoothCommandBuffer.setRenderTexture(this.faceMaskRT);
        this.smoothCommandBuffer.clearRenderTexture(true, true, new effect.Amaz.Color(0.0, 0.0, 0.0, 0.0), 1);
        (_a = this.faceMaskMatInstance) === null || _a === void 0 ? void 0 : _a.setTexture('maskTexture', this.faceMaskTexture);
        this.smoothCommandBuffer.drawMesh(this.componentMesh.getNative(), this.identityMatrix, this.faceMaskMatInstance.getNative(), 0, 0, this.tempMatPropertyBlock, false);
        this.smoothCommandBuffer.setRenderTexture(this.blurXRT);
        (_b = this.blurXMatInstance) === null || _b === void 0 ? void 0 : _b.getNative().setTex('inputTexture', this.inputRT);
        (_c = this.blurXMatInstance) === null || _c === void 0 ? void 0 : _c.setFloat('texBlurWidthOffset', 1.0 / this.width);
        (_d = this.blurXMatInstance) === null || _d === void 0 ? void 0 : _d.setFloat('texBlurHeightOffset', 1.0 / this.height);
        this.smoothCommandBuffer.blitWithMaterial(this.inputRT, this.blurXRT, this.blurXMatInstance.getNative(), 0, false);
        this.smoothCommandBuffer.setRenderTexture(this.blurYRT);
        (_e = this.blurYMatInstance) === null || _e === void 0 ? void 0 : _e.getNative().setTex('inputTexture', this.blurXRT);
        (_f = this.blurYMatInstance) === null || _f === void 0 ? void 0 : _f.setFloat('texBlurWidthOffset', 1.0 / this.width);
        (_g = this.blurYMatInstance) === null || _g === void 0 ? void 0 : _g.setFloat('texBlurHeightOffset', 1.0 / this.height);
        this.smoothCommandBuffer.blitWithMaterial(this.blurXRT, this.blurYRT, this.blurYMatInstance.getNative(), 0, false);
        this.smoothCommandBuffer.setRenderTexture(this.blendRT);
        (_h = this.blendMatInstance) === null || _h === void 0 ? void 0 : _h.getNative().setTex('inputTexture', this.inputRT);
        (_j = this.blendMatInstance) === null || _j === void 0 ? void 0 : _j.getNative().setTex('blurTexture', this.blurYRT);
        (_k = this.blendMatInstance) === null || _k === void 0 ? void 0 : _k.getNative().setTex('lutTexture', this.brightenTexture.getNative());
        this.smoothCommandBuffer.blitWithMaterial(this.inputRT, this.blendRT, this.blendMatInstance.getNative(), 0, false);
        this.smoothCommandBuffer.setRenderTexture(this.blurXRT);
        (_l = this.blurInnerMatInstance) === null || _l === void 0 ? void 0 : _l.getNative().setTex('inputTexture', this.blendRT);
        (_m = this.blurInnerMatInstance) === null || _m === void 0 ? void 0 : _m.setFloat('widthOffset', 1.0 / this.width);
        (_o = this.blurInnerMatInstance) === null || _o === void 0 ? void 0 : _o.setFloat('heightOffset', 1.0 / this.height);
        (_p = this.blurInnerMatInstance) === null || _p === void 0 ? void 0 : _p.setFloat('valueFactor', 20.0);
        this.smoothCommandBuffer.blitWithMaterial(this.blendRT, this.blurXRT, this.blurInnerMatInstance.getNative(), 0, false);
        this.smoothCommandBuffer.setRenderTexture(this.blurYRT);
        (_q = this.blurOuterMatInstance) === null || _q === void 0 ? void 0 : _q.getNative().setTex('inputTexture', this.blurXRT);
        (_r = this.blurOuterMatInstance) === null || _r === void 0 ? void 0 : _r.setFloat('widthOffset', 1.0 / this.width);
        (_s = this.blurOuterMatInstance) === null || _s === void 0 ? void 0 : _s.setFloat('heightOffset', 1.0 / this.height);
        (_t = this.blurOuterMatInstance) === null || _t === void 0 ? void 0 : _t.setFloat('valueFactor', 20.0);
        this.smoothCommandBuffer.blitWithMaterial(this.blurXRT, this.blurYRT, this.blurOuterMatInstance.getNative(), 0, false);
        this.smoothCommandBuffer.setRenderTexture(this.renderTexture);
        (_u = this.smoothMatInstance) === null || _u === void 0 ? void 0 : _u.getNative().setTex('inputTexture', this.inputRT);
        (_v = this.smoothMatInstance) === null || _v === void 0 ? void 0 : _v.getNative().setTex('blendTexture', this.blendRT);
        (_w = this.smoothMatInstance) === null || _w === void 0 ? void 0 : _w.getNative().setTex('blur3Texture', this.blurXRT);
        (_x = this.smoothMatInstance) === null || _x === void 0 ? void 0 : _x.getNative().setTex('blur4Texture', this.blurYRT);
        (_y = this.smoothMatInstance) === null || _y === void 0 ? void 0 : _y.getNative().setTex('facemaskTexture', this.faceMaskRT);
        (_z = this.smoothMatInstance) === null || _z === void 0 ? void 0 : _z.setFloat('smoothFactor', this.skinTextureIntensity > 0.6 ? (this.skinTextureIntensity - 0.3) : 0.3);
        (_0 = this.smoothMatInstance) === null || _0 === void 0 ? void 0 : _0.setFloat('smoothIntensity', this.skinTextureIntensity > 0.6 ? 1.0 : (this.skinTextureIntensity * 1.67));
        (_1 = this.smoothMatInstance) === null || _1 === void 0 ? void 0 : _1.setFloat('eyeBrillianceIntensity', this.eyeBrillianceIntensity);
        (_2 = this.smoothMatInstance) === null || _2 === void 0 ? void 0 : _2.setFloat('darkCirclesIntensity', this.darkCirclesIntensity);
        (_3 = this.smoothMatInstance) === null || _3 === void 0 ? void 0 : _3.setFloat('smileLinesIntensity', this.smileLinesIntensity);
        this.smoothCommandBuffer.blitWithMaterial(this.inputRT, this.renderTexture, this.smoothMatInstance.getNative(), 0, false);
        this.blitCommandBuffer.setRenderTexture(this.renderTexture);
        (_4 = this.blitMatInstance) === null || _4 === void 0 ? void 0 : _4.getNative().setTex('_MainTex', this.inputRT);
        this.blitCommandBuffer.blitWithMaterial(this.inputRT, this.renderTexture, this.blitMatInstance.getNative(), 0, false);
    }
    onFirstFrameUpdate() {
        const parentTrans = this.entity.getComponent('Transform').parent;
        for (let i = 0; i < parentTrans.children.size(); i++) {
            const child = parentTrans.children.get(i);
            if (child.entity.getComponent('Camera')) {
                this.faceMaskCamera = child.entity.getComponent('Camera');
                break;
            }
        }
        if (!this.faceMaskCamera) {
            return;
        }
        effect.Amaz.AmazingManager.addListener(this.faceMaskCamera, effect.Amaz.CameraEvent.RENDER_IMAGE_EFFECTS, this.renderFilterEffects, this);
    }
    onUpdate(deltaTime) {
        var _a;
        if (this.isFirstFrameUpdate) {
            this.onFirstFrameUpdate();
            this.isFirstFrameUpdate = false;
        }
        if (!this.faceMaskCamera) {
            return;
        }
        if (!this.faceMaskCamera.enabled || !this.faceMaskCamera.entity.visible || !((_a = this.entity) === null || _a === void 0 ? void 0 : _a.visible)) {
            return;
        }
        if (this.smoothMatInstance) {
            const smoothFactor = this.skinTextureIntensity > 0.6 ? (this.skinTextureIntensity - 0.3) : 0.3;
            const smoothIntensity = this.skinTextureIntensity > 0.6 ? 1.0 : (this.skinTextureIntensity * 1.6667);
            this.smoothMatInstance.setFloat('smoothFactor', smoothFactor);
            this.smoothMatInstance.setFloat('smoothIntensity', smoothIntensity);
            this.smoothMatInstance.setFloat('eyeBrillianceIntensity', this.eyeBrillianceIntensity);
            this.smoothMatInstance.setFloat('darkCirclesIntensity', this.darkCirclesIntensity);
            this.smoothMatInstance.setFloat('smileLinesIntensity', this.smileLinesIntensity);
        }
        if (this.skinTextureIntensity === 0
            && this.eyeBrillianceIntensity === 0
            && this.darkCirclesIntensity === 0
            && this.smileLinesIntensity === 0) {
            return;
        }
        this.updateSizeAndInitCommandBuffer();
        this.updateAlgorithmResult();
    }
    updateSizeAndInitCommandBuffer() {
        let currentWidth = 1280, currentHeight = 720;
        let outputRTChanged = false;
        if (this.faceMaskCamera && this.faceMaskCamera.renderTexture) {
            if (this.renderTexture !== this.faceMaskCamera.renderTexture) {
                outputRTChanged = true;
                this.usingCustomRenderTexture = true;
            }
            this.renderTexture = this.faceMaskCamera.renderTexture;
            currentWidth = this.faceMaskCamera.renderTexture.width;
            currentHeight = this.faceMaskCamera.renderTexture.height;
        }
        else {
            if (this.usingCustomRenderTexture) {
                outputRTChanged = true;
                this.usingCustomRenderTexture = false;
            }
            const builtinObj = effect.Amaz.AmazingManager.getSingleton('BuiltinObject');
            currentWidth = builtinObj.getInputTextureWidth();
            currentHeight = builtinObj.getInputTextureHeight();
        }
        const sizeChanged = (this.width !== currentWidth || this.height !== currentHeight);
        if (!sizeChanged && !outputRTChanged) {
            return;
        }
        this.width = currentWidth;
        this.height = currentHeight;
        this.setupRenderTextures();
        this.updateInputSize();
        this.rebuildCommandBuffers();
    }
    updateInputSize() {
        this.widthOffset = 1.0 / this.width;
        this.heightOffset = 1.0 / this.height;
        this.heightDownsample = Math.floor(this.widthDownsample * this.height / this.width);
        this.widthDownsampleOffset = 1.0 / this.widthDownsample;
        this.heightDownsampleOffset = 1.0 / this.heightDownsample;
        if (this.faceMaskRT) {
            this.faceMaskRT.height = this.heightDownsample;
        }
        if (this.blurXRT) {
            this.blurXRT.height = this.heightDownsample;
        }
        if (this.blurYRT) {
            this.blurYRT.height = this.heightDownsample;
        }
        if (this.faceMaskMatInstance) {
            const mvpMatrix = new effect.Amaz.Matrix4x4f();
            mvpMatrix.setTranslate(new effect.Amaz.Vector3f(-1, -1, 0));
            mvpMatrix.scale(new effect.Amaz.Vector3f(2, 2, 1));
            mvpMatrix.translate(new effect.Amaz.Vector3f(0, 1, 0));
            mvpMatrix.scale(new effect.Amaz.Vector3f(1, -1, 1));
            mvpMatrix.scale(new effect.Amaz.Vector3f(this.widthOffset, this.heightOffset, 1));
            this.faceMaskMatInstance.getNative().setMat4('uMVPMatrix', mvpMatrix);
        }
        if (this.blurXMatInstance) {
            this.blurXMatInstance.setFloat('texBlurWidthOffset', this.widthDownsampleOffset);
        }
        if (this.blurYMatInstance) {
            this.blurYMatInstance.setFloat('texBlurHeightOffset', this.heightDownsampleOffset);
        }
        if (this.blurInnerMatInstance) {
            this.blurInnerMatInstance.setFloat('widthOffset', this.widthDownsampleOffset);
            this.blurInnerMatInstance.setFloat('heightOffset', this.heightDownsampleOffset);
        }
        if (this.blurOuterMatInstance) {
            this.blurOuterMatInstance.setFloat('widthOffset', this.widthDownsampleOffset);
            this.blurOuterMatInstance.setFloat('heightOffset', this.heightDownsampleOffset);
        }
    }
    updateAlgorithmResult() {
        if (this.skinTextureIntensity === 0
            && this.eyeBrillianceIntensity === 0
            && this.darkCirclesIntensity === 0
            && this.smileLinesIntensity === 0) {
            return;
        }
        let algResult = algorithmManager.getAEAlgorithmResult();
        if (!algResult) {
            return;
        }
        const faceInfo = algResult.getAlgorithmInfo(this.graphName, this.algorithmNode, 'face', 0);
        if (faceInfo === null) {
            return;
        }
        this.validFaceCount = 0;
        const faceCount = faceInfo.getFaceCount();
        for (let faceIndex of this.faceIndexes) {
            if (faceIndex < faceCount) {
                const faceBaseInfo = faceInfo.getFaceBaseInfo(faceIndex);
                if (faceBaseInfo && faceBaseInfo.points_array) {
                    let newPointsArray = faceBaseInfo.points_array;
                    if (this.usingCustomRenderTexture) {
                        newPointsArray = this.transformFacePoints(faceBaseInfo.points_array);
                    }
                    this.meshTool.updateMeshWithFaceData106(this.meshType, newPointsArray, this.validFaceCount);
                    this.validFaceCount++;
                }
            }
        }
        if (this.componentMesh && this.componentMesh.getNative().getSubMesh(0)) {
            this.componentMesh.getNative().getSubMesh(0).indicesCount = this.validFaceCount * this.indicesCount;
        }
        if (this.smoothMatInstance) {
            this.smoothMatInstance.setFloat('useFaceMask', (this.validFaceCount > 0) ? 1.0 : 0.0);
        }
    }
    transformFacePoints(pointsArray) {
        const builtinObj = effect.Amaz.AmazingManager.getSingleton('BuiltinObject');
        const inputWidth = builtinObj.getInputTextureWidth();
        const inputHeight = builtinObj.getInputTextureHeight();
        const widthRatio = this.width / inputWidth;
        const heightOffset = inputHeight - this.height;
        const newPointsArray = new effect.Amaz.Vec2Vector();
        for (let i = 0; i < pointsArray.size(); i++) {
            const point = pointsArray.get(i);
            point.x = point.x * widthRatio;
            point.y = (heightOffset + point.y * this.height) / inputHeight;
            newPointsArray.pushBack(point);
        }
        return newPointsArray;
    }
    renderFilterEffects(user, obj, eventType) {
        const camera = obj;
        const comp = user;
        if (camera.enabled && comp.isInheritedEnabled() && eventType === effect.Amaz.CameraEvent.RENDER_IMAGE_EFFECTS) {
            if ((comp.skinTextureIntensity > 0.001
                || comp.eyeBrillianceIntensity > 0.001
                || comp.darkCirclesIntensity > 0.001
                || comp.smileLinesIntensity > 0.001)
                && comp.validFaceCount > 0) {
                camera.entity.scene.commitCommandBuffer(comp.smoothCommandBuffer);
            }
            else {
                camera.entity.scene.commitCommandBuffer(comp.blitCommandBuffer);
            }
        }
    }
    onDestroy() {
        if (this.faceMaskCamera !== null) {
            effect.Amaz.AmazingManager.removeListener(this.faceMaskCamera, effect.Amaz.CameraEvent.RENDER_IMAGE_EFFECTS, this.renderFilterEffects, this);
            this.faceMaskCamera = null;
        }
        this.isFirstFrameUpdate = true;
    }
    onLateUpdate(deltaTime) {
    }
};
__decorate([
    serialize,
    userPublicAPI()
], FaceRetouch.prototype, "skinTextureIntensity", void 0);
__decorate([
    serialize,
    userPublicAPI()
], FaceRetouch.prototype, "eyeBrillianceIntensity", void 0);
__decorate([
    serialize,
    userPublicAPI()
], FaceRetouch.prototype, "darkCirclesIntensity", void 0);
__decorate([
    serialize,
    userPublicAPI()
], FaceRetouch.prototype, "smileLinesIntensity", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "faceIndexes", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "graphName", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "algorithmNode", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "faceMaskMaterial", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "blitMaterial", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "blurXMaterial", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "blurYMaterial", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "blurInnerMaterial", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "blurOuterMaterial", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "blendMaterial", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "smoothMaterial", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "outputRenderTexture", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "brightenTexture", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "faceMaskTexture", void 0);
__decorate([
    serialize
], FaceRetouch.prototype, "faceMesh", void 0);
FaceRetouch = __decorate([
    registerClass()
], FaceRetouch);
exports.FaceRetouch = FaceRetouch;
hideAPIPrototype(FaceRetouch);
