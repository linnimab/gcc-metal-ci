
const {GraphUtils, BaseGroup, GraphManager, ControlFlow, GraphLifeCircleOrder, GraphLifeCircleType} = require("./Lib/Utils/ScriptNodeAPI");
const APJS = require("../amazingpro");

const { CGGetSceneObjectNode : CGGetSceneObjectNode100 } = require("./Lib/Nodes/CGGetSceneObjectNode100");
const { OnePointTouch : OnePointTouch200 } = require("./Lib/Nodes/OnePointTouch200");
const { CGSetVisibility : CGSetVisibility100 } = require("./Lib/Nodes/CGSetVisibility100");
const { CGFlipFlop : CGFlipFlop100 } = require("./Lib/Nodes/CGFlipFlop100");
const { CGSelect : CGSelect100 } = require("./Lib/Nodes/CGSelect100");
const { CGOnStart : CGOnStart100 } = require("./Lib/Nodes/CGOnStart100");
const { CGNot : CGNot100 } = require("./Lib/Nodes/CGNot100");


function globalVariableInit() {
    // init all variables
        if (this.APJScene && this.APJScene.assetManager) {
        } else {
            console.error("AssertManager is undefined");
        }

}

function layerNameInit() {
    this.layerNameMap[0] = "Default Layer";
    this.layerNameMap[1] = "Layer 1";
    this.layerNameMap[2] = "Layer 2";
    this.layerNameMap[3] = "Layer 3";
    this.layerNameMap[4] = "Layer 4";
    this.layerNameMap[5] = "Layer 5";
    this.layerNameMap[6] = "Layer 6";
    this.layerNameMap[7] = "Layer 7";
    this.layerNameMap[8] = "Layer 8";
    this.layerNameMap[9] = "Layer 9";
    this.layerNameMap[10] = "Layer 10";
    this.layerNameMap[11] = "Layer 11";
    this.layerNameMap[12] = "Layer 12";
    this.layerNameMap[13] = "Layer 13";
    this.layerNameMap[14] = "Layer 14";
    this.layerNameMap[15] = "Layer 15";
    this.layerNameMap[16] = "Layer 16";
    this.layerNameMap[17] = "Layer 17";
    this.layerNameMap[18] = "Layer 18";
    this.layerNameMap[19] = "Layer 19";
    this.layerNameMap[20] = "Layer 20";
    this.layerNameMap[21] = "Layer 21";
    this.layerNameMap[22] = "Layer 22";
    this.layerNameMap[23] = "Layer 23";
    this.layerNameMap[24] = "Layer 24";
    this.layerNameMap[25] = "Layer 25";
    this.layerNameMap[26] = "Layer 26";
    this.layerNameMap[27] = "Layer 27";
    this.layerNameMap[28] = "Layer 28";
    this.layerNameMap[29] = "Layer 29";
    this.layerNameMap[30] = "Layer 30";
    this.layerNameMap[31] = "Layer 31";
    this.layerNameMap[32] = "Layer 32";
    this.layerNameMap[33] = "Layer 33";
    this.layerNameMap[34] = "Layer 34";
    this.layerNameMap[35] = "Layer 35";
    this.layerNameMap[36] = "Layer 36";
    this.layerNameMap[37] = "Layer 37";
    this.layerNameMap[38] = "Layer 38";
    this.layerNameMap[39] = "Layer 39";
    this.layerNameMap[40] = "Layer 40";
    this.layerNameMap[41] = "Layer 41";
    this.layerNameMap[42] = "Layer 42";
    this.layerNameMap[43] = "Layer 43";
    this.layerNameMap[44] = "Layer 44";
    this.layerNameMap[45] = "Layer 45";
    this.layerNameMap[46] = "Layer 46";
    this.layerNameMap[47] = "Layer 47";
    this.layerNameMap[48] = "Layer 48";
    this.layerNameMap[49] = "Layer 49";
    this.layerNameMap[50] = "Layer 50";
    this.layerNameMap[51] = "Layer 51";
    this.layerNameMap[52] = "Layer 52";
    this.layerNameMap[53] = "Layer 53";
    this.layerNameMap[54] = "Layer 54";
    this.layerNameMap[55] = "Layer 55";
    this.layerNameMap[56] = "Layer 56";
    this.layerNameMap[57] = "Layer 57";
    this.layerNameMap[58] = "Layer 58";
    this.layerNameMap[59] = "Layer 59";
    this.layerNameMap[60] = "Layer 60";
    this.layerNameMap[61] = "Layer 61";
    this.layerNameMap[62] = "Layer 62";
    this.layerNameMap[63] = "Layer 63";
}

const { SystemGraph } = require("./Lib/Utils/SystemGraph");
class GraphSystem extends SystemGraph {
    constructor() {
        super();
        this.isPreview = false;
    }

    setGlobalDataInit() {
        const graphManager = GraphManager.getInstance();
        if (graphManager.variableInitFuncs) {
            graphManager.variableInitFuncs.push(globalVariableInit.bind(graphManager));
        }
        if (!graphManager.layerNameInitFunc) {
            graphManager.layerNameInitFunc = layerNameInit.bind(graphManager);
        }
    }

    registLifeCircle() {
        super.registLifeCircle();
        // *** regist total config
        this.registLifeCircleHandler(GraphLifeCircleType.onInit, {
            order: GraphLifeCircleOrder.onInit.graphConfig,
            tag: 'business generate config',
            fun: () => {
                this.usingBuiltInMediaPreview = true
                // algorithm subgraph map
                this.algorithmSubgraphMap = new Map();
            },
        });
        // *** load Resource
        this.registLifeCircleHandler(GraphLifeCircleType.onInit, {
            order: GraphLifeCircleOrder.onInit.loadResource,
            tag: 'load Resource',
            fun: () => {
                this.loadResource();
            },
        });
        // *** variable init
        this.registLifeCircleHandler(GraphLifeCircleType.onInit, {
            order: GraphLifeCircleOrder.onInit.variableInit,
            tag: 'variable init',
            fun: () => {
                this.variableInit();
            },
        });
        // *** node init
        this.registLifeCircleHandler(GraphLifeCircleType.onInit, {
            order: GraphLifeCircleOrder.onInit.nodeInit,
            tag: 'node init',
            fun: () => {
                this.nodeInit();
            },
        });
        // *** node connect
        this.registLifeCircleHandler(GraphLifeCircleType.onInit, {
            order: GraphLifeCircleOrder.onInit.nodeConnect,
            tag: 'node connect',
            fun: () => {
                this.nodeConnect();
            },
        });
        // *** update port data
        this.registLifeCircleHandler(GraphLifeCircleType.onUpdate, {
            order: GraphLifeCircleOrder.onUpdate.updatePortData,
            tag: 'update port data',
            fun: () => {
            },
        });
    }

    loadResource() {
        if (this.sys && this.sys.resource && this.sys.APJScene && this.sys.APJScene.assetManager) {
        } else {
          console.error("AssertManager is undefined");
        }
    }

    variableInit() {
        // member variable init
    // init all variables
        if (this.APJScene && this.APJScene.assetManager) {
        } else {
            console.error("AssertManager is undefined");
        }

    }

    nodeInit(){
        // node init
        this.createNode("GetSceneObject_1", CGGetSceneObjectNode100, 1, 1);



        this.initNodeMedaAndInputs("GetSceneObject_1",null,
            [{ portIndex: 0, value: null }]);
        this.createNode("GetSceneObject_3", CGGetSceneObjectNode100, 1, 1);



        this.initNodeMedaAndInputs("GetSceneObject_3",null,
            [{ portIndex: 0, value: GraphUtils.guidToPointer("5707488980385201757", "11953033857622949512") }]);
        this.createNode("FingerTouch1-Point_11", OnePointTouch200, 0, 6);



        this.createNode("SetVisibility_14", CGSetVisibility100, 3, 2);



        this.createNode("Flip-Flop_15", CGFlipFlop100, 1, 3);



        this.createNode("SetVisibility_16", CGSetVisibility100, 3, 2);



        this.createNode("LogicSelect_17", CGSelect100, 3, 1);



        this.initNodeMedaAndInputs("LogicSelect_17",{ valueType:"Bool", extraType:null},
            [{ portIndex: 0, value: false },{ portIndex: 1, value: false },{ portIndex: 2, value: true }]);
        this.createNode("Start_18", CGOnStart100, 0, 1);



        this.createNode("SetVisibility_19", CGSetVisibility100, 3, 2);



        this.createNode("Not_20", CGNot100, 1, 1);



        this.createNode("FingerTouch1-Point_27", OnePointTouch200, 0, 6);



        this.createNode("SetVisibility_30", CGSetVisibility100, 3, 2);



        this.createNode("Flip-Flop_31", CGFlipFlop100, 1, 3);



        this.createNode("SetVisibility_32", CGSetVisibility100, 3, 2);



        this.createNode("LogicSelect_33", CGSelect100, 3, 1);



        this.initNodeMedaAndInputs("LogicSelect_33",{ valueType:"Bool", extraType:null},
            [{ portIndex: 0, value: false },{ portIndex: 1, value: false },{ portIndex: 2, value: true }]);
        this.createNode("Start_34", CGOnStart100, 0, 1);



        this.createNode("SetVisibility_35", CGSetVisibility100, 3, 2);



        this.createNode("Not_36", CGNot100, 1, 1);



    }

    nodeConnect(){
        // hash value map
        this.hashValueMap = new Map();
        // regist hashValueList
        // init map to store if edge is in circle
        ControlFlow.clearEdgeIsInCircle();
        //node connection
        this.handleExecEdgeConnection("Flip-Flop_15", "SetVisibility_14", "0e631ded-03f0-03fa-c16a-8e413d7dec29", 1, 0,undefined, false, "ec319252-14b2-e4ef-ea3a-3575b3549087", { Input: "Normal", Output: "Normal" });
        this.handleExecEdgeConnection("Flip-Flop_15", "SetVisibility_16", "bde7d986-2db2-82de-e774-38b2dfdad8a3", 0, 0,undefined, false, "11d7ccf9-e3e5-1d32-696e-dee71baac9a0", { Input: "Normal", Output: "Normal" });
        this.handleExecEdgeConnection("Start_18", "SetVisibility_19", "c30613cf-378d-a106-dede-da141c226250", 0, 0,undefined, false, "7338542f-6d6e-f3fb-816c-90c006fc478b", { Input: "Normal", Output: "Normal" });
        this.handleDataEdgeConnection(false, "LogicSelect_17", "SetVisibility_19", 0, 2, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(false, "LogicSelect_17", "SetVisibility_14", 0, 2, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(false, "LogicSelect_17", "Not_20", 0, 0, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(false, "Not_20", "SetVisibility_16", 0, 2, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleExecEdgeConnection("Flip-Flop_31", "SetVisibility_30", "3a1e8db4-7ccc-cfcf-2945-5113c380d6dc", 1, 0,undefined, false, "efcd583f-cb47-5214-aa8e-af447025def9", { Input: "Normal", Output: "Normal" });
        this.handleExecEdgeConnection("Flip-Flop_31", "SetVisibility_32", "677cc16c-9cbd-a524-2bf7-a6c7d0169ed0", 0, 0,undefined, false, "c86d0dbd-a0b3-8303-bd06-98d5e644b63d", { Input: "Normal", Output: "Normal" });
        this.handleExecEdgeConnection("Start_34", "SetVisibility_35", "f2999b87-1c52-7e12-c375-d016dd2ed504", 0, 0,undefined, false, "82e8e84c-a198-8659-e62f-c76bf0095708", { Input: "Normal", Output: "Normal" });
        this.handleDataEdgeConnection(false, "LogicSelect_33", "SetVisibility_35", 0, 2, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(false, "LogicSelect_33", "SetVisibility_30", 0, 2, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(false, "LogicSelect_33", "Not_36", 0, 0, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(false, "Not_36", "SetVisibility_32", 0, 2, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(null, "GetSceneObject_1", "SetVisibility_14", 0, 1, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(null, "GetSceneObject_3", "SetVisibility_30", 0, 1, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        var triggerPortIds_17 = ["59b73bc8-cf4d-605c-f837-edae9055988b","2a03e151-f05e-d7dc-7176-162ed67f5d45","39625414-ddc2-561d-9e32-463a216d0d7d"];
        this.handleExecEdgeConnection("FingerTouch1-Point_11", "Flip-Flop_15", "c52fda55-e9fb-ae9e-a7f5-ddeadd47f40c", 1, 0,triggerPortIds_17, false, "39625414-ddc2-561d-9e32-463a216d0d7d", { Input: "Normal", Output: "Normal" });
        this.handleDataEdgeConnection(false, "", "LogicSelect_17", 1, 0, { Input: "Group", Output: "Normal" },()=>{return false},undefined, this.hashValueMap, "");
        var triggerPortIds_19 = ["c4b564fb-2340-9520-c0ce-bbcf6a593fa9"];
        this.handleExecEdgeConnection("FingerTouch1-Point_11", "", "4f31dd24-4d43-9c32-43d5-e1f672b69f23", 3, 1,triggerPortIds_19, false, "32f2580f-81cf-3eb3-7b84-7b9deba3b2b2", { Input: "Normal", Output: "Group" });
        this.handleDataEdgeConnection(null, "GetSceneObject_1", "SetVisibility_16", 0, 1, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(null, "GetSceneObject_1", "SetVisibility_19", 0, 1, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        var triggerPortIds_22 = ["af9ce1a3-dd49-5462-72b7-b2826579fa08","01f447d7-d5da-b334-00d3-ac8886219f82","617a647e-9c5d-6350-23ff-952d1eb57f21"];
        this.handleExecEdgeConnection("FingerTouch1-Point_27", "Flip-Flop_31", "a29b7eed-5269-4d92-3265-2d9eced975e7", 1, 0,triggerPortIds_22, false, "617a647e-9c5d-6350-23ff-952d1eb57f21", { Input: "Normal", Output: "Normal" });
        this.handleDataEdgeConnection(false, "", "LogicSelect_33", 1, 0, { Input: "Group", Output: "Normal" },()=>{return true},undefined, this.hashValueMap, "");
        var triggerPortIds_24 = ["0d184f42-8879-c12c-e5e7-33aaa6fb04f7"];
        this.handleExecEdgeConnection("FingerTouch1-Point_27", "", "77aba26b-e15b-3e82-a09c-3ddd40b23260", 3, 1,triggerPortIds_24, false, "ff0c999b-0711-689d-ce29-fd7bfb2aa3f9", { Input: "Normal", Output: "Group" });
        this.handleDataEdgeConnection(null, "GetSceneObject_3", "SetVisibility_32", 0, 1, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        this.handleDataEdgeConnection(null, "GetSceneObject_3", "SetVisibility_35", 0, 1, { Input: "Normal", Output: "Normal" },undefined,undefined, this.hashValueMap, "");
        //init callback table
        this.callbackNode.get(GraphLifeCircleType.beforeStart).push(this.nodes["FingerTouch1-Point_11"]);
        this.callbackNode.get(GraphLifeCircleType.onUpdate).push(this.nodes["FingerTouch1-Point_11"]);
        this.callbackNode.get(GraphLifeCircleType.onEvent).push(this.nodes["FingerTouch1-Point_11"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["FingerTouch1-Point_11"]);
        this.callbackNode.get(GraphLifeCircleType.beforeStart).push(this.nodes["SetVisibility_14"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["SetVisibility_14"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["Flip-Flop_15"]);
        this.callbackNode.get(GraphLifeCircleType.beforeStart).push(this.nodes["SetVisibility_16"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["SetVisibility_16"]);
        this.callbackNode.get(GraphLifeCircleType.onStart).push(this.nodes["Start_18"]);
        this.callbackNode.get(GraphLifeCircleType.beforeStart).push(this.nodes["SetVisibility_19"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["SetVisibility_19"]);
        this.callbackNode.get(GraphLifeCircleType.beforeStart).push(this.nodes["FingerTouch1-Point_27"]);
        this.callbackNode.get(GraphLifeCircleType.onUpdate).push(this.nodes["FingerTouch1-Point_27"]);
        this.callbackNode.get(GraphLifeCircleType.onEvent).push(this.nodes["FingerTouch1-Point_27"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["FingerTouch1-Point_27"]);
        this.callbackNode.get(GraphLifeCircleType.beforeStart).push(this.nodes["SetVisibility_30"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["SetVisibility_30"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["Flip-Flop_31"]);
        this.callbackNode.get(GraphLifeCircleType.beforeStart).push(this.nodes["SetVisibility_32"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["SetVisibility_32"]);
        this.callbackNode.get(GraphLifeCircleType.onStart).push(this.nodes["Start_34"]);
        this.callbackNode.get(GraphLifeCircleType.beforeStart).push(this.nodes["SetVisibility_35"]);
        this.callbackNode.get(GraphLifeCircleType.resetOnRecord).push(this.nodes["SetVisibility_35"]);
    }
};

exports.GraphSystem = GraphSystem;
