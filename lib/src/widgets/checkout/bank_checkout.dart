import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:paystack_flutter_sa/src/api/service/bank_service.dart';
import 'package:paystack_flutter_sa/src/api/service/contracts/banks_service_contract.dart';
import 'package:paystack_flutter_sa/src/common/paystack.dart';
import 'package:paystack_flutter_sa/src/models/bank.dart';
import 'package:paystack_flutter_sa/src/models/charge.dart';
import 'package:paystack_flutter_sa/src/models/checkout_response.dart';
import 'package:paystack_flutter_sa/src/transaction/bank_transaction_manager.dart';
import 'package:paystack_flutter_sa/src/widgets/buttons.dart';
import 'package:paystack_flutter_sa/src/widgets/checkout/base_checkout.dart';
import 'package:paystack_flutter_sa/src/widgets/checkout/checkout_widget.dart';
import 'package:paystack_flutter_sa/src/widgets/common/extensions.dart';
import 'package:paystack_flutter_sa/src/widgets/input/account_field.dart';

class BankCheckout extends StatefulWidget {
  final Charge charge;
  final OnResponse<CheckoutResponse> onResponse;
  final ValueChanged<bool> onProcessingChange;
  final BankServiceContract service;
  final String publicKey;

  const BankCheckout({
    super.key,
    required this.charge,
    required this.onResponse,
    required this.onProcessingChange,
    required this.service,
    required this.publicKey,
  });

  @override
  _BankCheckoutState createState() => _BankCheckoutState(onResponse);
}

class _BankCheckoutState extends BaseCheckoutMethodState<BankCheckout> {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _animation;
  var _autoValidate = AutovalidateMode.disabled;
  late Future<List<Bank>?>? _futureBanks;
  Bank? _currentBank;
  BankAccount? _account;
  var _loading = false;

  _BankCheckoutState(OnResponse<CheckoutResponse> onResponse) : super(onResponse, CheckoutMethod.bank);

  @override
  void initState() {
    _futureBanks = widget.service.fetchSupportedBanks();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.ease,
      ),
    );
    _animation.addListener(_rebuild);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget buildAnimatedChild() {
    return Container(
      alignment: Alignment.center,
      child: FutureBuilder<List<Bank>?>(
        future: _futureBanks,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          Widget widget;
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              widget = Center(
                child: Container(
                  width: 50.0,
                  height: 50.0,
                  margin: const EdgeInsets.symmetric(vertical: 30.0),
                  child: const CircularProgressIndicator(
                    strokeWidth: 3.0,
                  ),
                ),
              );
              break;
            case ConnectionState.done:
              widget = snapshot.hasData ? _getCompleteUI(snapshot.data) : retryButton();
              break;
            default:
              widget = retryButton();
              break;
          }
          return widget;
        },
      ),
    );
  }

  Widget _getCompleteUI(List<Bank> banks) {
    var container = Container();
    return Container(
      child: Form(
        autovalidateMode: _autoValidate,
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              height: 10.0,
            ),
            _currentBank == null
                ? const Icon(
                    Icons.account_balance,
                    size: 35.0,
                  )
                : container,
            _currentBank == null
                ? const SizedBox(
                    height: 20.0,
                  )
                : container,
            Text(
              _currentBank == null ? 'Choose your bank to start the payment' : 'Enter your acccount number',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
            ),
            const SizedBox(
              height: 20.0,
            ),
            DropdownButtonHideUnderline(
                child: InputDecorator(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey, width: 0.5)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: context.colorScheme().secondary, width: 1.0)),
                hintText: 'Tap here to choose',
              ),
              isEmpty: _currentBank == null,
              child: DropdownButton<Bank>(
                value: _currentBank,
                isDense: true,
                onChanged: (Bank? newValue) {
                  setState(() {
                    _currentBank = newValue;
                    _controller.forward();
                  });
                },
                items: banks.map((Bank value) {
                  return DropdownMenuItem<Bank>(
                    value: value,
                    child: Text(value.name!),
                  );
                }).toList(),
              ),
            )),
            ScaleTransition(
              scale: _animation,
              child: _currentBank == null
                  ? container
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          height: 15.0,
                        ),
                        AccountField(onSaved: (String? value) => _account = BankAccount(_currentBank, value)),
                        const SizedBox(
                          height: 20.0,
                        ),
                        AccentButton(onPressed: _validateInputs, showProgress: _loading, text: 'Verify Account')
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _validateInputs() {
    FocusScope.of(context).requestFocus(FocusNode());
    final FormState form = _formKey.currentState!;
    if (form.validate()) {
      form.save();
      widget.charge.account = _account;
      widget.onProcessingChange(true);
      setState(() => _loading = true);
      _chargeAccount();
    } else {
      setState(() => _autoValidate = AutovalidateMode.always);
    }
  }

  void _chargeAccount() async {
    final response = await BankTransactionManager(charge: widget.charge, service: widget.service, context: context, publicKey: widget.publicKey).chargeBank();

    if (!mounted) return;

    setState(() => _loading = false);
    onResponse(response);
  }

  Widget retryButton() {
    banksMemo = null;
    banksMemo = AsyncMemoizer();
    _futureBanks = widget.service.fetchSupportedBanks();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
      child: AccentButton(onPressed: () => setState(() {}), showProgress: false, text: 'Display banks'),
    );
  }

  void _rebuild() {
    setState(() {
      // Rebuild in order to animate views.
    });
  }
}
