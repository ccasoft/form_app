class CompanyData {
  final String companyId;
  final String companyName;
  final String address;
  final String gstNumber;

  CompanyData({
    required this.companyId,
    required this.companyName,
    required this.address,
    required this.gstNumber,
  });

  factory CompanyData.fromMap(String id, Map<String, dynamic> map) {
    return CompanyData(
      companyId: id,
      companyName: map['companyName'] ?? '',
      address: map['address'] ?? '',
      gstNumber: map['gstNumber'] ?? '',
    );
  }
}

class RouteData {
  final String routeId;
  final String routeName;
  final String description;
  final List<String> transportNames;

  /// Ordered delivery stops / pins for this route (up to 10)
  final List<String> stops;

  RouteData({
    required this.routeId,
    required this.routeName,
    required this.description,
    required this.transportNames,
    this.stops = const [],
  });

  factory RouteData.fromMap(String id, Map<String, dynamic> map) {
    return RouteData(
      routeId: id,
      routeName: map['routeName'] ?? '',
      description: map['description'] ?? '',
      transportNames:
          (map['transportNames'] as List<dynamic>?)?.cast<String>() ?? [],
      stops: (map['stops'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routeId': routeId,
      'routeName': routeName,
      'description': description,
      'transportNames': transportNames,
      'stops': stops,
    };
  }
}

class InvoiceData {
  PartyData partyData;
  String invoiceNumber;
  String invoiceDate;
  String invoiceAmount;
  int timestamp;
  String validityDate;
  String ewayBillNumber;
  String companyName;
  String transportName;
  String id;
  List<String> selectedInvoicesIdList;
  String orderType;
  String specialRemarks;
  int stage;
  String? routeName;
  String? vehicleNumber;
  String? seriesId;
  String? seriesName;
  // Dispatch fields (pre-filled in Ack screen)
  String? dispatchDate;
  String? tripNumber;
  String? openingKm;
  String? lrNumber;
  String? lrDate;
  String? packCase;
  String? looseCase;
  String? totalCase;
  String? ackPhotoUrl;
  // Telecalling follow-up (Cold Chain / Cool Chain / Special orders only).
  // telecallStatus: 'pending' | 'not_delivered' | 'delivered'
  String? telecallStatus;
  int? telecallAttempts;
  int? telecallLastCalledAt; // epoch ms
  String? telecallContactPerson; // person at party who confirmed delivery
  String? telecallTemperature; // temperature goods were received at
  int? telecallDeliveryTime; // epoch ms — when goods were actually delivered

  InvoiceData({
    required this.partyData,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.invoiceAmount,
    required this.timestamp,
    required this.validityDate,
    required this.ewayBillNumber,
    required this.companyName,
    required this.transportName,
    required this.selectedInvoicesIdList,
    required this.id,
    required this.orderType,
    this.specialRemarks = '',
    this.stage = 1,
    this.routeName,
    this.vehicleNumber,
    this.seriesId,
    this.seriesName,
    this.dispatchDate,
    this.tripNumber,
    this.openingKm,
    this.lrNumber,
    this.lrDate,
    this.packCase,
    this.looseCase,
    this.totalCase,
    this.ackPhotoUrl,
    this.telecallStatus,
    this.telecallAttempts,
    this.telecallLastCalledAt,
    this.telecallContactPerson,
    this.telecallTemperature,
    this.telecallDeliveryTime,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> json) {
    return InvoiceData(
      partyData:
          PartyData.fromJson(json['partyData'] as Map<String, dynamic>? ?? {}),
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      invoiceDate: json['invoiceDate'] as String? ?? '',
      invoiceAmount: json['invoiceAmount'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? 0,
      validityDate: json['validityDate'] as String? ?? '',
      ewayBillNumber: json['ewayBillNumber'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      transportName: json['transportName'] as String? ?? '',
      id: json['id'] as String? ?? '',
      orderType: json['orderType'] as String? ?? '',
      specialRemarks: json['specialRemarks'] as String? ?? '',
      stage: json['stage'] as int? ?? 1,
      selectedInvoicesIdList:
          (json['selectedInvoicesIdList'] as List<dynamic>?)?.cast<String>() ??
              [],
      routeName: json['routeName'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      seriesId: json['seriesId'] as String?,
      seriesName: json['seriesName'] as String?,
      dispatchDate: json['dispatchDate'] as String?,
      tripNumber: json['tripNumber'] as String?,
      openingKm: json['openingKm'] as String?,
      lrNumber: json['lrNumber'] as String?,
      lrDate: json['lrDate'] as String?,
      packCase: json['packCase'] as String?,
      looseCase: json['looseCase'] as String?,
      totalCase: json['totalCase'] as String?,
      ackPhotoUrl: json['ackPhotoUrl'] as String?,
      telecallStatus: json['telecallStatus'] as String?,
      telecallAttempts: (json['telecallAttempts'] as num?)?.toInt(),
      telecallLastCalledAt: (json['telecallLastCalledAt'] as num?)?.toInt(),
      telecallContactPerson: json['telecallContactPerson'] as String?,
      telecallTemperature: json['telecallTemperature'] as String?,
      telecallDeliveryTime: (json['telecallDeliveryTime'] as num?)?.toInt(),
    );
  }
}

class PartyData {
  String partyId;
  String partyName;
  String address;
  String contactNumber1;
  String contactNumber2;
  String contactPerson;
  String transportName;
  String routeName;
  String stopName;
  int stopSeq;
  List<String> companyIds;
  bool needsCheque;

  PartyData({
    required this.partyId,
    required this.partyName,
    required this.address,
    required this.contactNumber1,
    required this.contactNumber2,
    required this.contactPerson,
    required this.transportName,
    this.routeName = '',
    this.stopName = '',
    this.stopSeq = 999,
    this.companyIds = const [],
    this.needsCheque = false,
  });

  factory PartyData.fromJson(Map<String, dynamic> json) {
    return PartyData(
      partyId: json['partyId'] as String? ?? '',
      partyName: json['partyName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      contactNumber1: json['contactNumber1'] as String? ?? '',
      contactNumber2: json['contactNumber2'] as String? ?? '',
      contactPerson: json['contactPerson'] as String? ?? '',
      transportName: json['transportName'] as String? ?? '',
      routeName: json['routeName'] as String? ?? '',
      stopName: json['stopName'] as String? ?? '',
      stopSeq: (json['stopSeq'] as num?)?.toInt() ?? 999,
      companyIds: (json['companyIds'] as List<dynamic>?)?.cast<String>() ?? [],
      needsCheque: json['needsCheque'] as bool? ?? false,
    );
  }
}

class AcknowledgementData {
  String companyName;
  String ewayBillNumber;
  String invoiceAmount;
  String invoiceDate;
  String invoiceNumber;
  String looseCase;
  String lrDate;
  String lrNumber;
  String openingKm;
  String packCase;
  String partyId;
  String partyName;
  int timestamp;
  String totalCase;
  String transportName;
  String tripNumber;
  String validityDate;
  int stage;
  String? vehicleNumber;
  String? routeName;

  AcknowledgementData({
    required this.companyName,
    required this.ewayBillNumber,
    required this.invoiceAmount,
    required this.invoiceDate,
    required this.invoiceNumber,
    required this.looseCase,
    required this.lrDate,
    required this.lrNumber,
    required this.openingKm,
    required this.packCase,
    required this.partyId,
    required this.partyName,
    required this.timestamp,
    required this.totalCase,
    required this.transportName,
    required this.tripNumber,
    required this.validityDate,
    this.stage = 3,
    this.vehicleNumber,
    this.routeName,
  });

  factory AcknowledgementData.fromJson(Map<String, dynamic> json) {
    return AcknowledgementData(
      companyName: json['companyName'] as String? ?? '',
      ewayBillNumber: json['ewayBillNumber'] as String? ?? '',
      invoiceAmount: json['invoiceAmount'] as String? ?? '',
      invoiceDate: json['invoiceDate'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      looseCase: json['looseCase'] as String? ?? '',
      lrDate: json['lrDate'] as String? ?? '',
      lrNumber: json['lrNumber'] as String? ?? '',
      openingKm: json['openingKm'] as String? ?? '',
      packCase: json['packCase'] as String? ?? '',
      partyId: json['partyId'] as String? ?? '',
      partyName: json['partyName'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? 0,
      totalCase: json['totalCase'] as String? ?? '',
      transportName: json['transportName'] as String? ?? '',
      tripNumber: json['tripNumber'] as String? ?? '',
      validityDate: json['validityDate'] as String? ?? '',
      stage: json['stage'] as int? ?? 3,
      vehicleNumber: json['vehicleNumber'] as String?,
      routeName: json['routeName'] as String?,
    );
  }
}

class InvoiceAcknowledgementData {
  PartyData partyData;
  String invoiceNumber;
  String invoiceDate;
  String invoiceAmount;
  int timestamp;
  String validityDate;
  String ewayBillNumber;
  String transportName;
  String id;
  List<String> selectedInvoicesIdList;
  String orderType;
  String specialRemarks;
  String companyName;
  String looseCase;
  String lrDate;
  String lrNumber;
  String openingKm;
  String packCase;
  String partyId;
  String partyName;
  String totalCase;
  String tripNumber;
  int stage;
  String? routeName;
  String? vehicleNumber;
  String? chequeNumber;
  String? chequeDate;
  String? chequeAmount;
  String? bankName;
  String? dispatchDate;
  String? ackPhotoUrl; // Firebase Storage URL of acknowledgement photo
  bool isCancelled; // True = invoice cancelled / not to be supplied

  InvoiceAcknowledgementData({
    required this.partyData,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.invoiceAmount,
    required this.timestamp,
    required this.validityDate,
    required this.ewayBillNumber,
    required this.transportName,
    required this.selectedInvoicesIdList,
    required this.id,
    required this.orderType,
    this.specialRemarks = '',
    required this.companyName,
    required this.looseCase,
    required this.lrDate,
    required this.lrNumber,
    required this.openingKm,
    required this.packCase,
    required this.partyId,
    required this.partyName,
    required this.totalCase,
    required this.tripNumber,
    this.stage = 1,
    this.routeName,
    this.vehicleNumber,
    this.chequeNumber,
    this.chequeDate,
    this.chequeAmount,
    this.bankName,
    this.dispatchDate,
    this.ackPhotoUrl,
    this.isCancelled = false,
  });

  factory InvoiceAcknowledgementData.fromJson(Map<String, dynamic> json) {
    return InvoiceAcknowledgementData(
      partyData:
          PartyData.fromJson(json['partyData'] as Map<String, dynamic>? ?? {}),
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      invoiceDate: json['invoiceDate'] as String? ?? '',
      invoiceAmount: json['invoiceAmount'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? 0,
      validityDate: json['validityDate'] as String? ?? '',
      ewayBillNumber: json['ewayBillNumber'] as String? ?? '',
      transportName: json['transportName'] as String? ?? '',
      id: json['id'] as String? ?? '',
      orderType: json['orderType'] as String? ?? '',
      specialRemarks: json['specialRemarks'] as String? ?? '',
      selectedInvoicesIdList:
          (json['selectedInvoicesIdList'] as List<dynamic>?)?.cast<String>() ??
              [],
      companyName: json['companyName'] as String? ?? '',
      looseCase: json['looseCase'] as String? ?? '',
      lrDate: json['lrDate'] as String? ?? '',
      lrNumber: json['lrNumber'] as String? ?? '',
      openingKm: json['openingKm'] as String? ?? '',
      packCase: json['packCase'] as String? ?? '',
      partyId: json['partyId'] as String? ?? '',
      partyName: json['partyName'] as String? ?? '',
      totalCase: json['totalCase'] as String? ?? '',
      tripNumber: json['tripNumber'] as String? ?? '',
      stage: json['stage'] as int? ?? 1,
      routeName: json['routeName'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      chequeNumber: json['chequeNumber'] as String?,
      chequeDate: json['chequeDate'] as String?,
      chequeAmount: json['chequeAmount'] as String?,
      bankName: json['bankName'] as String?,
      dispatchDate: json['dispatchDate'] as String?,
      ackPhotoUrl: json['ackPhotoUrl'] as String?,
      isCancelled: json['isCancelled'] as bool? ?? false,
    );
  }
}
