//@ScriptComponent
const Amaz = effect.Amaz;
const {ContourBodyType, ContoursManager} = require('./ContoursManager');
/**
 * FindContour will build sprites around the largest portrait contour.
 * PRD - https://bytedance.us.feishu.cn/docx/GofYdjh8po4744xtqVluWTl2sld
 * EHI PRD - https://bytedance.us.feishu.cn/docx/Mwn1dBGpzo7V0fxOuV8uH3EQsLf
 * Dependencies - MeshRenderer, AnimSeqComponent.  both added via script
 * Algorithm dependencies - FindPortraitContour, Matting
 */
const LineType = {
    Line: 0,
    Dot: 1,
}

class FindContour{

    constructor() {
        this.name = 'FindContour';
        this._curTime = 0;
        this._screenWidth = Amaz.AmazingManager.getSingleton('BuiltinObject').getInputTextureWidth();
        this._screenHeight = Amaz.AmazingManager.getSingleton('BuiltinObject').getInputTextureHeight();
        this._size = new Amaz.Vector2f(25.0, 25.0);
    }

    onStart() {
        this._curTime = 0;
        this.findContourMeshRender = this.entity.addComponent("MeshRenderer");
        this.findContourMeshRender.autoSortingOrder = this.autoSortingOrder;
        this.findContourMeshRender.sortingOrder = this.sortingOrder;

        if(!this.resultMesh){
            if (this.lineType === LineType.Dot) {
                this.resultMesh = this.createDotMesh();
            } else {
                this.resultMesh = this.createLineMesh();
            }
        }

        if(!this.resultMat){
            //create material by default mat, cannot use this.defaultMaterial directly,otherwise,it will cause mutil components use same one mat, change
            //one mat param, all component will be change
            this.resultMat = this.createMaterialInstance("findContourMat", this.defaultMaterial.xshader);
        }
        this.cvTex = new Amaz.Texture2D();
        this.cvTex.filterMin = Amaz.FilterMode.NEAREST;
        this.cvTex.filterMag = Amaz.FilterMode.NEAREST;
        this.resultMat.setTex("_ContourTex", this.cvTex);

        this.findContourMeshRender.mesh = this.resultMesh;
        this.findContourMeshRender.material = this.resultMat;
        this.findContourMeshRender.enabled = false;
        this.lastNumber = this.number
    }

    onUpdate(dt) {
        if (this.number !== this.lastNumber && this.lineType === LineType.Dot) {
            this.updateMeshVertices(this.findContourMeshRender.mesh);
        }
        this.checkProperties();
        this.lastNumber = this.number;
        this._curTime = this._curTime + dt;
        this._updateMeshRenderMaterial();

        //update material
        if (this.missingTex) {
            //missing tex dont influce by color
            this.findContourMeshRender.material.setVec4("_AlbedoColor",new Amaz.Vector4f(1,1,1,1));
            this.findContourMeshRender.material.setVec4("_AlbedoColor2",new Amaz.Vector4f(1,1,1,1));
        } else {
            this.findContourMeshRender.material.setVec4("_AlbedoColor",new Amaz.Vector4f(this.color.r,this.color.g,this.color.b,this.color.a));
            this.findContourMeshRender.material.setVec4("_AlbedoColor2",new Amaz.Vector4f(this.endColor.r,this.endColor.g,this.endColor.b,this.endColor.a));
        }
    }

    checkProperties() {
        this.size.x = Math.max(0, Math.min(100, this.size.x));
        this.size.y = Math.max(0, Math.min(100, this.size.y));
        this.number = Math.max(0, Math.min(500, this.number));
        this.range.x = Math.max(-360, Math.min(360, this.range.x));
        this.range.y = Math.max(this.range.x, Math.min(360, this.range.y));
        if (this.range.y - this.range.x > 360) {
            this.range.y = this.range.x + 360;
        }
        this.startOffset = this.range.x / 360;
        this.spread = (this.range.y - this.range.x) / 360 * 100;
        this.speed = Math.max(-100, Math.min(100, this.speed));
        this.perimeterGrowth = Math.max(-100, Math.min(100, this.perimeterGrowth));
        this.brushSize = Math.max(10, Math.min(100, this.brushSize));
        this.depthBottom = Math.max(0, Math.min(100, this.depthBottom));
        this.depthThreshold = Math.max(0, Math.min(100, this.depthThreshold));
    }

    onLateUpdate(dt) {
        ContoursManager.getInstance().clearContoursCache();
    }
    
    set size(size) {
        if (size instanceof Amaz.Vector2f) {
            this._size = size;
        }
        else {
            this._size = new Amaz.Vector2f(size, size);
        }
    }

    get size() {
        return this._size;
    }

    _updateMeshRenderMaterial() {
        const result = Amaz.AmazingManager.getSingleton("Algorithm").getAEAlgorithmResult();//RTTI functions for getting algorithm results
        if (!result) {
            if ( this.findContourMeshRender) {
                this.findContourMeshRender.enabled = false;
            }
            console.log("FindContour: no algorithm result");
            return;
        }

        const dilateSize = this.lineType === LineType.Dot ? 0 : this.perimeterGrowth/3;
        const contourResult = ContoursManager.getInstance().getOrFindContour(this.objectType, this.depthBottom / 100, this.depthThreshold / 100, dilateSize);

        if (!contourResult || !contourResult.pointMat) {
            if ( this.findContourMeshRender) {
                this.findContourMeshRender.enabled = false;
            }
            return;
        }
        const pointMat = contourResult.pointMat;
        const contourPointCount = contourResult.pointCount;

        this.resultMat.setFloat("_ContourPointCount", contourPointCount);
        this.resultMat.setFloat("_StartOffset", this.startOffset);
        this.resultMat.setFloat("_Spread", this.spread / 100);
        this.resultMat.setFloat("_Scale", this.perimeterGrowth);
        this.resultMat.setInt("_GradientType", this.gradientType);
        this._checkCurTime();
        this.resultMat.setFloat("_CurrentTime", this._curTime);
        if (this.lineType === LineType.Dot) {
            this._updateDotUniform();
        } else {
            this._updateLineUniform();
        }
        this.resultMat.setFloat("_Speed", this.speed);
        this.resultMat.setVec2("_Offset",  new Amaz.Vector2f(this.offset.x, this.offset.y));
        this.resultMat.setInt("_FlipX", this.flipHorizontally ? 1 : 0);
        this.resultMat.setInt("_FlipY", this.flipVertically ? 1 : 0);
        this.resultMat.setFloat("_ScreenRatio", this._screenHeight / this._screenWidth);

        const imgByCV = pointMat.toImage(Amaz.PixelFormat.RGBA8Unorm, true);
        this.cvTex.storage(imgByCV);

        this.findContourMeshRender.enabled = true;
    }

    _checkCurTime() {
        if (this._curTime * this.speed / 500.0 > 3 || this._curTime * this.speed / 500.0 < -3) {
            this._curTime = 0;
        }
    }

    _updateDotUniform() {
        this.resultMat.setVec2("_PointSize", new Amaz.Vector2f(this.size.x, this.size.y));
        this.resultMat.setFloat("_PointCount", this.number);
        let rotationMode = 0;
        if (this.rotationAlignment === 'ROT_ALIGN_NORMAL') {
            rotationMode = 1;
        } else if (this.rotationAlignment === 'ROT_ALIGN_TAN') {
            rotationMode = 2;
        } else if (this.rotationAlignment === 'ROT_ALIGN_RANDOM') {
            rotationMode = 3;
        }
        this.resultMat.setInt("_RotateMode", rotationMode);
        this.resultMat.setFloat("_RotateSpeed", this.rotationSpeed);
        this.resultMat.setFloat("_NoiseFrequency", this.noiseFrequency);
        this.resultMat.setFloat("_NoiseAmplitude", this.noiseAmplitude);
        this.resultMat.setTex("_AlbedoTexture", this.itemTexture);
        let ratio = this.itemTexture.width /this.itemTexture.height;
        this.findContourMeshRender.material.setFloat("_Ratio", ratio); //ratio will make tex dont stretch
        return;
    }

    _updateLineUniform() {
        this.resultMat.setFloat("_LineSize", this.brushSize / 720 * this._screenWidth * 1.5);
        this.resultMat.setInt("_FillTexture", this.isLineSolid ? 0 : 1);
        this.resultMat.setFloat("_LineDistanceFacetor", this.lineDistanceFactor);
        this.resultMat.setTex("_AlbedoTexture", this.brushTexture);
        let ratio = this.brushTexture.width / this.brushTexture.height;
        this.findContourMeshRender.material.setFloat("_Ratio", ratio); //ratio will make tex dont stretch
        return;
    }


    onEnable(){
        if ( this.findContourMeshRender) {
            this.findContourMeshRender.enabled = true;
        }
        console.log("[onEnable]",this.name);
    }

    onDisable() {
        if ( this.findContourMeshRender) {
            this.findContourMeshRender.enabled = false;
        }
        console.log("[onDisable]",this.name);
    }

    createMaterialInstance(name, xshader) {
        var mat = new Amaz.Material();
        mat.name = name;
        mat.xshader = xshader;
        return mat;
    }

    createDotMesh() {
        let mesh = new Amaz.Mesh()
        let subMesh = new Amaz.SubMesh()
        // setup attributes
        let attribs = new Amaz.Vector()
        let attribPos = new Amaz.VertexAttribDesc()
        attribPos.semantic = Amaz.VertexAttribType.POSITION
        attribs.pushBack(attribPos);
        let attribuv = new Amaz.VertexAttribDesc();
        attribuv.semantic = Amaz.VertexAttribType.TEXCOORD0;
        attribs.pushBack(attribuv);
        mesh.vertexAttribs = attribs
        subMesh.primitive = Amaz.Primitive.TRIANGLES
        subMesh.mesh = mesh
        mesh.addSubMesh(subMesh)

        this.updateMeshVertices(mesh);
        return mesh;
    }

    updateMeshVertices(mesh) {
        let gIndex = 0;
        const verticesList = new Float32Array(4*5*this.number);  //use this type push vertice data,it will improve performance; 4 vert, every vert have 5 data(xyz, uv)
        const indices = new Uint16Array(6*this.number); //use this type push vertice data,it will improve performance; two triangle, 6 index
        for (let i = 0; i < this.number; i++) {
            for (let j = 0; j < 4; j++) {
                const uv = {};
                if (j === 0) {
                    uv.x = 0;
                    uv.y = 0;
                }
                else if (j === 1) {
                    uv.x = 1;
                    uv.y = 0;
                }
                else if (j === 2) {
                    uv.x = 1;
                    uv.y = 1;
                }
                else if (j === 3) {
                    uv.x = 0;
                    uv.y = 1;
                }

                let index = (i*4+j)*5;
                verticesList[index] = i;
                verticesList[index+1] = j;
                verticesList[index+2] = 0;
                verticesList[index+3] = uv.x;
                verticesList[index+4] = uv.y;
            }
            const indice = [0, 1, 2, 0, 2, 3];
            for (let j = 0; j < 6; j++) {
                indices[i*6+j] = gIndex + indice[j];
            }
            gIndex += 4;
        }

        let vertices = new Amaz.FloatVector();
        let indicesVector = new Amaz.UInt16Vector();
        Amaz.AmazingUtil.arrayBufferToPrimitiveVector(verticesList.buffer , vertices);
        Amaz.AmazingUtil.arrayBufferToPrimitiveVector(indices.buffer , indicesVector);
        mesh.vertices = vertices;
        mesh.submeshes.get(0).indices16 = indicesVector;
    }

    createLineMesh() {
        let mesh = new Amaz.Mesh();
        let subMesh = new Amaz.SubMesh();
        // setup attributes
        let attribs = new Amaz.Vector();
        let attribPos = new Amaz.VertexAttribDesc();
        attribPos.semantic = Amaz.VertexAttribType.POSITION;
        attribs.pushBack(attribPos);
        mesh.vertexAttribs = attribs;
        subMesh.primitive = Amaz.Primitive.POINTS;
        subMesh.mesh = mesh;
        mesh.addSubMesh(subMesh);

        const CONTOUR_DATA_SIZE = 64;
        const CONTOUR_DATA_SIZE_INV = 1.0 / CONTOUR_DATA_SIZE;
        const verticesList = new Float32Array(3 * CONTOUR_DATA_SIZE * CONTOUR_DATA_SIZE);
        const indices = new Uint16Array(CONTOUR_DATA_SIZE * CONTOUR_DATA_SIZE);
        for (let j = 0; j <= CONTOUR_DATA_SIZE - 1; j++) {
            for (let i = 0; i <= CONTOUR_DATA_SIZE - 1; i++) {
                let index = ((i * CONTOUR_DATA_SIZE) + j)
                indices[index] = index;
                let texelU = j * CONTOUR_DATA_SIZE_INV  + 0.5 * CONTOUR_DATA_SIZE_INV;
                let texelV = i * CONTOUR_DATA_SIZE_INV + 0.5 * CONTOUR_DATA_SIZE_INV;
                verticesList[3*index] = index;
                verticesList[3*index+1] = texelU;
                verticesList[3*index+2] = texelV;
            }
        }
        let vertices = new Amaz.FloatVector();
        let indicesVector = new Amaz.UInt16Vector();
        Amaz.AmazingUtil.arrayBufferToPrimitiveVector(verticesList.buffer , vertices);
        Amaz.AmazingUtil.arrayBufferToPrimitiveVector(indices.buffer , indicesVector);
        mesh.vertices = vertices;
        mesh.submeshes.get(0).indices16 = indicesVector;
        return mesh;
    }

    onRelease() {
        this.removeMeshRenderer();
    }

    onDestroy(sys) {
        this.removeMeshRenderer();
    }

    removeMeshRenderer() {
        if (this.findContourMeshRender) {
            this.entity.removeComponent(this.findContourMeshRender);
            this.findContourMeshRender = undefined;
        }
    }
}

exports.FindContour = FindContour;

