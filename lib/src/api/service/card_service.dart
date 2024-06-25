import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:paystack_flutter/src/api/model/transaction_api_response.dart';
import 'package:paystack_flutter/src/api/service/base_service.dart';
import 'package:paystack_flutter/src/api/service/contracts/cards_service_contract.dart';
import 'package:paystack_flutter/src/common/exceptions.dart';
import 'package:paystack_flutter/src/common/extensions.dart';
import 'package:paystack_flutter/src/common/my_strings.dart';

class CardService with BaseApiService implements CardServiceContract {
  @override
  Future<TransactionApiResponse> chargeCard(Map<String, String?> fields) async {
    var url = '$baseUrl/charge/mobile_charge';

    http.Response response = await http.post(url.toUri(), body: fields, headers: headers);
    var body = response.body;

    var statusCode = response.statusCode;

    switch (statusCode) {
      case HttpStatus.ok:
        Map<String, dynamic> responseBody = json.decode(body);
        return TransactionApiResponse.fromMap(responseBody);
      case HttpStatus.gatewayTimeout:
        throw ChargeException('Gateway timeout error');
      default:
        throw ChargeException(Strings.unKnownResponse);
    }
  }

  @override
  Future<TransactionApiResponse> validateCharge(Map<String, String?> fields) async {
    var url = '$baseUrl/charge/validate';

    http.Response response = await http.post(url.toUri(), body: fields, headers: headers);
    var body = response.body;

    var statusCode = response.statusCode;
    if (statusCode == HttpStatus.ok) {
      Map<String, dynamic> responseBody = json.decode(body);
      return TransactionApiResponse.fromMap(responseBody);
    } else {
      throw CardException('validate charge transaction failed with '
          'status code: $statusCode and response: $body');
    }
  }

  @override
  Future<TransactionApiResponse> reQueryTransaction(String? trans) async {
    var url = '$baseUrl/requery/$trans';

    http.Response response = await http.get(url.toUri(), headers: headers);
    var body = response.body;
    var statusCode = response.statusCode;
    if (statusCode == HttpStatus.ok) {
      Map<String, dynamic> responseBody = json.decode(body);
      return TransactionApiResponse.fromMap(responseBody);
    } else {
      throw ChargeException('requery transaction failed with status code: '
          '$statusCode and response: $body');
    }
  }
}