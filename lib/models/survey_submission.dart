/// Mirrors the `public."Taru"` table (served by `/api/tauru`).
/// JSON keys match the column names exactly (including case).
class SurveySubmission {
  final int? id;

  final String? ulbName;
  final String? district;
  final String? mohallaName;
  final String? wardNoOrName;
  final String? propertyId;
  final String? houseNo;
  final String? ownerName;
  final String? fatherOrHusbandName;
  final int? membersInHouse;
  final String? address;
  final String? mobileNo;
  final String? natureOfHouse;

  final String? widthofRoadInFront;
  final String? typeofconstruction;
  final String? useofhouse;

  final double? frontWidthofPlotInFeet;
  final double? depthofPlotInFeet;
  final double? totalAreaInFeet;
  final double? builtUpArea;
  final double? openArea;

  final String? ifmixed;

  final double? firstFloorArea;
  final double? secondFloorArea;
  final double? thirdFloorArea;
  final double? fourthFloorArea;

  final double? commercialArea;
  final double? totalBuiltUpArea;

  final String? occupancyStatus;

  final String? frontPhotoUrl;
  final String? rightSidePhotoUrl;
  final String? leftSidePhotoUrl;

  final double? dataLat;
  final double? dataLng;

  final String? waterConnection;
  final String? sewerConnection;

  final String? submittedAt;
  final int? submittedBy;

  final String? remarks;

  final DateTime? updatedAt;
  final int? updatedBy;

  final String? floorNo;

  const SurveySubmission({
    this.id,
    this.ulbName,
    this.district,
    this.mohallaName,
    this.wardNoOrName,
    this.propertyId,
    this.houseNo,
    this.ownerName,
    this.fatherOrHusbandName,
    this.membersInHouse,
    this.address,
    this.mobileNo,
    this.natureOfHouse,
    this.widthofRoadInFront,
    this.typeofconstruction,
    this.useofhouse,
    this.frontWidthofPlotInFeet,
    this.depthofPlotInFeet,
    this.totalAreaInFeet,
    this.builtUpArea,
    this.openArea,
    this.ifmixed,
    this.firstFloorArea,
    this.secondFloorArea,
    this.thirdFloorArea,
    this.fourthFloorArea,
    this.commercialArea,
    this.totalBuiltUpArea,
    this.occupancyStatus,
    this.frontPhotoUrl,
    this.rightSidePhotoUrl,
    this.leftSidePhotoUrl,
    this.dataLat,
    this.dataLng,
    this.waterConnection,
    this.sewerConnection,
    this.submittedAt,
    this.submittedBy,
    this.remarks,
    this.updatedAt,
    this.updatedBy,
    this.floorNo,
  });

  static double? _toDouble(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

  static int? _toInt(dynamic v) =>
      v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

  static String? _toStr(dynamic v) => v?.toString();

  factory SurveySubmission.fromJson(Map<String, dynamic> json) {
    return SurveySubmission(
      id: _toInt(json['id']),
      ulbName: _toStr(json['ulbName']),
      district: _toStr(json['district']),
      mohallaName: _toStr(json['mohallaName']),
      wardNoOrName: _toStr(json['wardNoOrName']),
      propertyId: _toStr(json['propertyId']),
      houseNo: _toStr(json['houseNo']),
      ownerName: _toStr(json['ownerName']),
      fatherOrHusbandName: _toStr(json['fatherOrHusbandName']),
      membersInHouse: _toInt(json['membersInHouse']),
      address: _toStr(json['address']),
      mobileNo: _toStr(json['mobileNo']),
      natureOfHouse: _toStr(json['natureOfHouse']),
      widthofRoadInFront: _toStr(json['WidthofRoadInFront']),
      typeofconstruction: _toStr(json['Typeofconstruction']),
      useofhouse: _toStr(json['Useofhouse']),
      frontWidthofPlotInFeet: _toDouble(json['frontWidthofPlotInFeet']),
      depthofPlotInFeet: _toDouble(json['depthofPlotInFeet']),
      totalAreaInFeet: _toDouble(json['totalAreaInFeet']),
      builtUpArea: _toDouble(json['builtUpArea']),
      openArea: _toDouble(json['openArea']),
      ifmixed: _toStr(json['ifmixed']),
      firstFloorArea: _toDouble(json['firstFloorArea']),
      secondFloorArea: _toDouble(json['secondFloorArea']),
      thirdFloorArea: _toDouble(json['thirdFloorArea']),
      fourthFloorArea: _toDouble(json['fourthFloorArea']),
      commercialArea: _toDouble(json['commercialArea']),
      totalBuiltUpArea: _toDouble(json['totalBuiltUpArea']),
      occupancyStatus: _toStr(json['occupancyStatus']),
      frontPhotoUrl: _toStr(json['frontPhotoUrl']),
      rightSidePhotoUrl: _toStr(json['rightSidePhotoUrl']),
      leftSidePhotoUrl: _toStr(json['leftSidePhotoUrl']),
      dataLat: _toDouble(json['dataLat']),
      dataLng: _toDouble(json['dataLng']),
      waterConnection: _toStr(json['waterConnection']),
      sewerConnection: _toStr(json['sewerConnection']),
      submittedAt: _toStr(json['submittedAt']),
      submittedBy: _toInt(json['submittedBy']),
      remarks: _toStr(json['remarks']),
      updatedAt:
          json['updatedAt'] == null
              ? null
              : DateTime.tryParse(json['updatedAt'].toString()),
      updatedBy: _toInt(json['updatedBy']),
      floorNo: _toStr(json['floorNo']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ulbName': ulbName,
      'district': district,
      'mohallaName': mohallaName,
      'wardNoOrName': wardNoOrName,
      'propertyId': propertyId,
      'houseNo': houseNo,
      'ownerName': ownerName,
      'fatherOrHusbandName': fatherOrHusbandName,
      'membersInHouse': membersInHouse,
      'address': address,
      'mobileNo': mobileNo,
      'natureOfHouse': natureOfHouse,
      'WidthofRoadInFront': widthofRoadInFront,
      'Typeofconstruction': typeofconstruction,
      'Useofhouse': useofhouse,
      'frontWidthofPlotInFeet': frontWidthofPlotInFeet,
      'depthofPlotInFeet': depthofPlotInFeet,
      'totalAreaInFeet': totalAreaInFeet,
      'builtUpArea': builtUpArea,
      'openArea': openArea,
      'ifmixed': ifmixed,
      'firstFloorArea': firstFloorArea,
      'secondFloorArea': secondFloorArea,
      'thirdFloorArea': thirdFloorArea,
      'fourthFloorArea': fourthFloorArea,
      'commercialArea': commercialArea,
      'totalBuiltUpArea': totalBuiltUpArea,
      'occupancyStatus': occupancyStatus,
      'frontPhotoUrl': frontPhotoUrl,
      'rightSidePhotoUrl': rightSidePhotoUrl,
      'leftSidePhotoUrl': leftSidePhotoUrl,
      'dataLat': dataLat,
      'dataLng': dataLng,
      'waterConnection': waterConnection,
      'sewerConnection': sewerConnection,
      'submittedAt': submittedAt,
      if (submittedBy != null) 'submittedBy': submittedBy,
      'remarks': remarks,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (updatedBy != null) 'updatedBy': updatedBy,
      'floorNo': floorNo,
    };
  }
}
