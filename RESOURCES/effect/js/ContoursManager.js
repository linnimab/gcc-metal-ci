const Amaz = effect.Amaz;
const cv = Amaz.JSWrapCV;
const cvUtil = Amaz.JSWrapCVUtil;

const ContourBodyType = {
  Human: 0,
  Pet: 1,
  Hand: 2,
  Cloth: 3,
  Sky: 4,
  Ground: 5,
  Building: 6,
  Skin: 7,
  Depth: 8
};

class ContoursManager {
  static getInstance() {
    if (!Amaz.ContoursManagerInstance) {
        Amaz.ContoursManagerInstance = new ContoursManager();
        Amaz.ContoursManagerInstance._init();
    }
    return Amaz.ContoursManagerInstance;
  }

  _init() {
    this._typeToContours = new Map();
  }

  _generateKey(type, threshold1, threshold2, dilateSize) {
    return `${type}_${threshold1}_${threshold2}_${dilateSize}`;
  }

  getOrFindContour(type, bottom = 0.1, threshold=0.5, dilateSize=0) {
    const key = this._generateKey(type, bottom, threshold, dilateSize);
    let cacheResult = this._typeToContours.get(key);
    if (cacheResult) {
      return cacheResult;
    }
    const result = Amaz.AmazingManager.getSingleton("Algorithm").getAEAlgorithmResult();
    if (!result) {
      return undefined;
    }

    let maskMat = undefined;
    switch (type) {
      case ContourBodyType.Human:
        maskMat = this._getHumanMaskMat(result);
        break;
      case ContourBodyType.Pet:
        maskMat = this._getPetMaskMat(result);
        break;
      case ContourBodyType.Hand:
        maskMat = this._getHandMaskMat(result);
        break;
      case ContourBodyType.Cloth:
        maskMat = this._getClothMaskMat(result);
        break;
      case ContourBodyType.Sky:
        maskMat = this._getSkyMaskMat(result);
        break;
      case ContourBodyType.Ground:
        maskMat = this._getGroundMaskMat(result);
        break;
      case ContourBodyType.Building:
        maskMat = this._getBuildingMaskMat(result);
        break;
      case ContourBodyType.Skin:
        maskMat = this._getSkinMaskMat(result);
        break;
      case ContourBodyType.Depth:
        maskMat = this._getDepthMaskMat(result, bottom, threshold);
        break;
    }
    if (!maskMat) {
      return undefined;
    }
    const res = this._findLongestContour(maskMat, dilateSize);
    this._typeToContours.set(key, res);
    return res;
  }

  _getHumanMaskMat(algoResult) {
    const mattingInfo = algoResult.getBgInfo();
    if (mattingInfo) {
      const mattingmask = mattingInfo.bgMask;
      const mat = cv.Mat(mattingmask);
      if (mat.channels !== 1) {
        cv.cvtColor(mat, mat, 11);
      }
      return mat;
    }
    return undefined;
  }

  _getPetMaskMat(algoResult) {
    const mattingInfo = algoResult.getPetMattingInfo();
    if (mattingInfo) {
      const mattingmask = mattingInfo.mask0;
      return cv.Mat(mattingmask);
    }
    return undefined;
  }

  _getHandMaskMat(algoResult) {
    const handInfo = algoResult.getHandInfo(0);
    if (handInfo) {
      const handmask = handInfo.image;
      let DstMat = cv.Mat();
      cv.threshold(cv.Mat(handmask), DstMat, 0.6 * 255, 255, 0);
      return DstMat;
    }
    return undefined;
  }

  _getClothMaskMat(algoResult) {
    const clothInfo = algoResult.getClothesSegInfo();
    if (clothInfo) {
      const clothmask = clothInfo.alphaMask;
      let DstMat = cv.Mat();
      cv.threshold(cv.Mat(clothmask), DstMat, 0.6 * 255, 255, 0);
      return DstMat;
    }
    return undefined;
  }

  _getSkyMaskMat(algoResult) {
    const skyInfo = algoResult.getSkyInfo();
    if (skyInfo) {
      const skyMask = skyInfo.skyMask;
      let DstMat = cv.Mat();
      cv.threshold(cv.Mat(skyMask), DstMat, 0.6 * 255, 255, 0);
      return DstMat;
    }
    return undefined;
  }

  _getGroundMaskMat(algoResult) {
    const groundInfo = algoResult.getGroundSegInfo();
    if (groundInfo) {
      const groundMask = groundInfo.groundMask;
      let DstMat = cv.Mat();
      cv.threshold(cv.Mat(groundMask), DstMat, 0.6 * 255, 255, 0);
      return DstMat;
    }
    return undefined;
  }

  _getBuildingMaskMat(algoResult) {
    const buildingInfo = algoResult.getBuildingSegInfo();
    if (buildingInfo) {
      const buildingMask = buildingInfo.mask;
      const mat4 = cv.Mat(buildingMask);
      let outputs = [];
      cv.split(mat4, outputs);
      let DstMat = cv.Mat();
      cv.threshold(outputs[1], DstMat, 0.3 * 255, 255, 0);
      return DstMat;
    }
    return undefined;
  }

  _getSkinMaskMat(algoResult) {
    const skinInfo = algoResult.getSkinSegInfo();
    if (skinInfo) {
      const skinMask = skinInfo.data;
      let DstMat = cv.Mat();
      const mat = cv.Mat(skinMask);
      if (mat.channels !== 1) {
        cv.cvtColor(mat, mat, 11);
      }
      cv.threshold(mat, DstMat, 0.6 * 255, 255, 0);
      return DstMat;
    }
    return undefined;
  }

  _getDepthMaskMat(algoResult, bottom, threshold) {
    if (bottom > threshold) {
      const temp = threshold;
      threshold = bottom;
      bottom = temp;
    }
    const mattingInfo = algoResult.getDepthEstimationInfo('', '', 0);
    if (mattingInfo) {
      const mattingmask = mattingInfo.image;
      const SrcMat = cv.Mat(mattingmask);
      const DstMat = cv.Mat();
      cv.threshold(SrcMat, DstMat, threshold * 255, 255, 1);
      const DstMat2 = cv.Mat();
      cv.threshold(SrcMat, DstMat2, bottom * 255, 255, 0);
      let DstMat3 = cv.Mat();
      cv.bitwise_and(DstMat, DstMat2, DstMat3);
      return DstMat3;
    }
    return undefined;
  }

  _findLongestContour(maskMat, dilateSize) {
    let contoursArray = new Array();
    const DstMat = cv.Mat();
    dilateSize = Math.ceil(dilateSize);
    if (dilateSize > 0) {
      let elem = cv.getStructuringElement(2, [dilateSize, dilateSize]);
      cv.dilate(maskMat, DstMat, elem);
    } else if (dilateSize < 0) {
      let elem = cv.getStructuringElement(2, [-dilateSize, -dilateSize]);
      cv.erode(maskMat, DstMat, elem);
    }
    cv.findContours(DstMat.cols>0 ? DstMat : maskMat, contoursArray, 0, 1);
    const contoursVec = this._jsArrayLongestToAmzVec(contoursArray).get(0);
    let pointMat = cvUtil.contour2Mesh(contoursVec, [maskMat.cols, maskMat.rows]);
    return {
      pointMat: pointMat,
      pointCount: contoursVec.size(),
    };
  }

  _jsArrayLongestToAmzVec(contours) {
    let longestIndex = 0;
    let maxLength = 0;

    for (let index = 0; index < contours.length; index++) {
        let contour = contours[index];
        if (contour.byteLength > maxLength) {
            maxLength = contour.byteLength;
            longestIndex = index;
        }
    }
    
    let vec2Vec = new Amaz.Vec2Vector();
    let result = new Amaz.Vector();
    Amaz.AmazingUtil.arrayBufferToPrimitiveVector(contours[longestIndex], vec2Vec);
    result.pushBack(vec2Vec);
    return result;
  }

  clearContoursCache() {
    this._typeToContours.clear();
  }
};

exports.ContoursManager = ContoursManager;
exports.ContourBodyType = ContourBodyType;
ContoursManager._instance = null;