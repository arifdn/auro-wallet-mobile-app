import 'dart:math';
import 'package:auro_wallet/common/components/AddressSelect/AddressDropdownButton.dart';
import 'package:auro_wallet/common/components/AddressSelect/AddressSelectionDropdown.dart'; 
import 'package:auro_wallet/store/settings/types/contactData.dart';
import 'package:auro_wallet/utils/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:auro_wallet/common/components/txConfirmDialog.dart';
import 'package:auro_wallet/common/components/feeSelector.dart';
import 'package:auro_wallet/common/components/inputItem.dart';
import 'package:auro_wallet/common/components/normalButton.dart';
import 'package:auro_wallet/common/components/advancedTransferOptions.dart';
import 'package:auro_wallet/common/consts/settings.dart';
import 'package:auro_wallet/page/account/scanPage.dart';
import 'package:auro_wallet/page/settings/contact/contactListPage.dart';
import 'package:auro_wallet/service/api/api.dart';
import 'package:auro_wallet/store/app.dart';
import 'package:auro_wallet/store/assets/types/transferData.dart';
import 'package:auro_wallet/store/wallet/wallet.dart';
import 'package:auro_wallet/utils/UI.dart';
import 'package:auro_wallet/utils/colorsUtil.dart';
import 'package:auro_wallet/utils/format.dart';
import 'package:auro_wallet/utils/i18n/index.dart';
import 'package:mobx/mobx.dart';
import 'package:auro_wallet/store/assets/types/fees.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TransferPage extends StatefulWidget {
  const TransferPage(this.store);

  static final String route = '/assets/transfer';
  final AppStore store;

  @override
  _TransferPageState createState() => _TransferPageState(store);
}

class _TransferPageState extends State<TransferPage> {
  _TransferPageState(this.store);

  final AppStore store;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountCtrl = new TextEditingController();
  final TextEditingController _toAddressCtrl = new TextEditingController();
  final TextEditingController _memoCtrl = new TextEditingController();
  final TextEditingController _nonceCtrl = new TextEditingController();
  final TextEditingController _feeCtrl = new TextEditingController();
  late ReactionDisposer _monitorFeeDisposer;
  final addressFocusNode = FocusNode();
  bool submitDisabled = true;
  bool submitting = false;
  double? currentFee;
  bool inputDirty = false;
  String? contactName;
  ContactData? _contactData;
  List<DropdownAddressItem>  addressList = [];

  var _loading = Observable(true);

  @override
  void initState() {
    super.initState();
    _onFeeLoaded(store.assets!.transferFees);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _monitorFeeDisposer =
          reaction((_) => store.assets!.transferFees, _onFeeLoaded);
      _amountCtrl.addListener(_monitorSummitStatus);
      _toAddressCtrl.addListener(_monitorSummitStatus);
      _toAddressCtrl.addListener(_onAddressChange);
      _feeCtrl.addListener(_onFeeInputChange);
      _loadData();
      _loadAddressData();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _toAddressCtrl.dispose();
    _memoCtrl.dispose();
    _nonceCtrl.dispose();
    _feeCtrl.dispose();
    _monitorFeeDisposer();
    super.dispose();
  }

  void _onFeeInputChange() {
    setState(() {
      inputDirty = true;
      if (_feeCtrl.text.isNotEmpty) {
        currentFee = double.parse(Fmt.parseNumber(_feeCtrl.text));
      } else {
        currentFee = null;
      }
    });
  }

  void _onAddressChange() {
    if (_contactData != null) {
      if (_toAddressCtrl.text == _contactData!.address) {
        setState(() {
          contactName = _contactData!.name;
        });
      } else if (contactName != null) {
        setState(() {
          contactName = null;
        });
      }
    }
  }

  void _monitorSummitStatus() {
    if (_toAddressCtrl.text.isEmpty || _amountCtrl.text.isEmpty) {
      if (!submitDisabled) {
        setState(() {
          submitDisabled = true;
        });
      }
    } else if (submitDisabled) {
      setState(() {
        submitDisabled = false;
      });
    }
  }

  Future<void> _onScan() async {
    var canOpen = await CameraUtils.canOpenCamera();
    if (!canOpen) {
      return;
    }
    addressFocusNode.unfocus();
    addressFocusNode.canRequestFocus = false;
    Future.delayed(Duration(milliseconds: 100), () {
      addressFocusNode.canRequestFocus = true;
    });
    var to = await Navigator.of(context).pushNamed(ScanPage.route);
    if (to == null) return;
    String address = (to as QRCodeAddressResult).address;
    _toAddressCtrl.text = address;
  }

  Future<bool> _validate() async {
    String? amountError = _validateAmount();
    if (amountError != null) {
      UI.toast(amountError);
      return false;
    }
    String? addressError = await _validateAddress();
    if (addressError != null) {
      UI.toast(addressError);
      return false;
    }
    return true;
  }

  bool _isAllTransfer() {
    var accountInfo = store.assets!.accountsInfo[store.wallet!.currentAddress];
    if (accountInfo != null) {
      double amount = double.parse(Fmt.parseNumber(_amountCtrl.text));
      if (amount == Fmt.bigIntToDouble(accountInfo.total, COIN.decimals)) {
        return true;
      }
    }
    return false;
  }

  void _handleSubmit() async {
    _unFocus();
    if (_nonceCtrl.text.isEmpty && currentFee == null) {
      if (_loading.value) {
        // waiting nonce data from server and user does not choose fee
        setState(() {
          submitting = true;
        });
        await asyncWhen((r) => _loading.value == false);
        setState(() {
          submitting = false;
        });
      }
    }
    if (await _validate()) {
      double amount = double.parse(Fmt.parseNumber(_amountCtrl.text));
      String toAddress = _toAddressCtrl.text.trim();
      String memo = _memoCtrl.text.trim();
      double fee;
      int inferredNonce;
      bool shouldShowNonce = false;
      if (_nonceCtrl.text.isNotEmpty) {
        shouldShowNonce = true;
        inferredNonce = int.parse(_nonceCtrl.text);
      } else {
        inferredNonce = store
            .assets!.accountsInfo[store.wallet!.currentAddress]!.inferredNonce;
      }
      fee = _feeCtrl.text.isNotEmpty
          ? double.parse(Fmt.parseNumber(_feeCtrl.text))
          : currentFee!;
      double amountToTransfer = amount;
      if (_isAllTransfer()) {
        amountToTransfer = amount - fee;
      }
      final Map<String, String> i18n = I18n.of(context).main;
      var txItems = [
        TxItem(
            label: i18n['toAddress']!,
            value: toAddress,
            type: TxItemTypes.address),
        TxItem(
            label: i18n['fromAddress']!,
            value: store.wallet!.currentAddress,
            type: TxItemTypes.address),
        TxItem(
            label: i18n['fee']!,
            value: '${fee.toString()} ${COIN.coinSymbol}',
            type: TxItemTypes.amount),
      ];
      if (shouldShowNonce) {
        txItems.add(TxItem(
            label: "Nonce ", value: '$inferredNonce', type: TxItemTypes.text));
      }
      if (memo.isNotEmpty) {
        txItems.add(
            TxItem(label: i18n['memo2']!, value: memo, type: TxItemTypes.text));
      }
      final isWatchMode =
          store.wallet!.currentWallet.walletType == WalletStore.seedTypeNone;
      final isLedger =
          store.wallet!.currentWallet.walletType == WalletStore.seedTypeLedger;
      bool exited = false;
      await UI.showTxConfirm(
          context: context,
          title: i18n['sendDetail']!,
          isLedger: isLedger,
          items: txItems,
          disabled: isWatchMode,
          buttonText: isWatchMode ? i18n['watchMode'] : i18n['confirm'],
          headLabel: i18n['amount']!,
          headValue: Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Fmt.priceFloor(amountToTransfer,
                    lengthFixed: 2, lengthMax: COIN.decimals),
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                COIN.coinSymbol,
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          onConfirm: () async {
            String? privateKey;
            if (!isLedger) {
              String? password = await UI.showPasswordDialog(
                  context: context,
                  wallet: store.wallet!.currentWallet,
                  inputPasswordRequired: false);
              if (password == null) {
                return false;
              }
              privateKey = await webApi.account.getPrivateKey(
                  store.wallet!.currentWallet,
                  store.wallet!.currentWallet.currentAccountIndex,
                  password);
              if (privateKey == null) {
                UI.toast(i18n['passwordError']!);
                return false;
              }
            }
            Map txInfo = {
              "privateKey": privateKey,
              "accountIndex": store.wallet!.currentWallet.currentAccountIndex,
              "fromAddress": store.wallet!.currentAddress,
              "toAddress": toAddress,
              "amount": amountToTransfer,
              "fee": fee,
              "nonce": inferredNonce,
              "memo": memo,
            };
            TransferData? data;
            if (isLedger) {
              print('start sign ledger');
              final tx = await webApi.account
                  .ledgerSign(txInfo, context: context, isDelegation: false);
              if (tx == null) {
                return false;
              }
              if (!exited) {
                data = await webApi.account
                    .sendTxBody(tx, context: context, isDelegation: false);
              }
            } else {
              data =
                  await webApi.account.signAndSendTx(txInfo, context: context);
            }
            if (mounted && !exited) {
              // if(data != null) {
              //   await Navigator.pushReplacementNamed(context, TransactionDetailPage.route, arguments: data);
              // } else {
              //   Navigator.popUntil(context, ModalRoute.withName('/'));
              // }
              Navigator.popUntil(context, ModalRoute.withName('/'));
              globalBalanceRefreshKey.currentState!.show();
              return true;
            }
            return false;
          });
      exited = true;
      return;
    }
  }

  Future<void> _loadData() async {
    await Future.wait([
      webApi.assets.fetchAccountInfo(),
      webApi.assets.queryTxFees(),
    ]);
    runInAction(() {
      _loading.value = false;
    });
  }

  Future<void> onSelect(ContactData addressInfo) async {
    _toAddressCtrl.text = addressInfo.address;
    setState(() {
      _contactData = addressInfo;
      contactName = addressInfo.name;
    });
  }
  Future<void> _loadAddressData()async {
    var currentAddress = store.wallet!.currentAddress;
    var accountList= store.wallet!.accountListAll.map((accountItem) => {
          "name": Fmt.accountName(accountItem), 
          "address": accountItem.pubKey, 
          "type": AddressItemTypes.account
    }).toList();
    var contactsList = store.settings!.contactList.map((addressBookItem) => {
          "name": addressBookItem.name, 
          "address": addressBookItem.address, 
          "type": AddressItemTypes.addressbook
    }).toList();
    List<Map<String, dynamic>> tempList = [...accountList,...contactsList];
    List<DropdownAddressItem> convertedList = tempList.where((element) => element["address"] != currentAddress).map((data) {
      return DropdownAddressItem(
        name: data["name"],
        address: data["address"],
        type: data["type"],
        addressKey: data["name"]+ data["address"] + data["type"].toString().split('.')[1]
      );
    }).toList();
    if(convertedList.isEmpty){
      addressList.add(DropdownAddressItem(
        name: "",
        address: "",
        type: AddressItemTypes.empty,
        addressKey: AddressItemTypes.empty.toString().split('.')[1]
      ));
    }else{
      addressList.addAll(convertedList);
    }
  }

  void _onFeeLoaded(Fees fees) {
    if (inputDirty) {
      return;
    }
    print('_onFeeLoaded');
    setState(() {
      currentFee = fees.medium;
      _feeCtrl.text = currentFee.toString();
      print('set fee ctr');
    });
  }

  Future<String?> _validateAddress() async {
    final Map<String, String> dic = I18n.of(context).main;
    String toAddress = _toAddressCtrl.text.trim();
    bool isValid = await webApi.account.isAddressValid(toAddress);
    if (!isValid) {
      return dic['sendAddressError']!;
    }
    return null;
  }

  void _unFocus() {
    FocusScope.of(context).requestFocus(new FocusNode());
  }

  String? _validateAmount() {
    bool isAllTransferFlag = _isAllTransfer();
    final Map<String, String> dic = I18n.of(context).main;
    BigInt available =
        store.assets!.accountsInfo[store.wallet!.currentAddress]?.total ??
            BigInt.from(0);
    final int decimals = COIN.decimals;
    double fee = _feeCtrl.text.isNotEmpty
        ? double.parse(Fmt.parseNumber(_feeCtrl.text))
        : currentFee!;
    if (_amountCtrl.text.isEmpty) {
      return dic['amountError']!;
    }
    if (isAllTransferFlag) {
      if (double.parse(Fmt.parseNumber(_amountCtrl.text)) - fee <= 0) {
        return dic['balanceNotEnough']!;
      }
    } else if (double.parse(Fmt.parseNumber(_amountCtrl.text)) >=
        available / BigInt.from(pow(10, decimals)) - fee) {
      return dic['balanceNotEnough']!;
    }
    return null;
  }

  void _onChooseFee(double fee) {
    _feeCtrl.text = fee.toString();
    setState(() {
      currentFee = fee;
    });
  }

  void _onChooseContact() async {
    var contact = await Navigator.of(context)
        .pushNamed(ContactListPage.route, arguments: {"isToSelect": true});
    if (contact != null) {
      ContactData contactData = contact as ContactData;
      _toAddressCtrl.text = contactData.address;
      setState(() {
        _contactData = contactData;
        contactName = contactData.name;
      });
    }
  }

  void _onAllClick() {
    var accountInfo = store.assets!.accountsInfo[store.wallet!.currentAddress];
    if (accountInfo != null) {
      _amountCtrl.text =
          Fmt.bigIntToDouble(accountInfo.total, COIN.decimals).toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        var theme = Theme.of(context).textTheme;
        final Map<String, String> dic = I18n.of(context).main;
        final int decimals = COIN.decimals;
        BigInt available =
            store.assets!.accountsInfo[store.wallet!.currentAddress]?.total ??
                BigInt.from(0);
        final fees = store.assets!.transferFees;
        double realBottom = MediaQuery.of(context).viewInsets.bottom;
        double nextBottom = realBottom > 0 ? realBottom - 120 : realBottom;
        nextBottom = nextBottom.isNegative ? 0 : nextBottom ;
        return Scaffold(
          appBar: AppBar(
            title: Text(dic['send']!),
            shadowColor: Colors.transparent,
            centerTitle: true,
            actions: <Widget>[
              IconButton(
                icon: SvgPicture.asset(
                  'assets/images/assets/scanner.svg',
                  width: 20,
                  height: 20,
                  color: Colors.black,
                ),
                onPressed: _onScan,
              )
            ],
          ),
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.white,
          body: SafeArea(
            maintainBottomViewPadding: true,
            child: Builder(
              builder: (BuildContext context) {
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
                        children: <Widget>[
                          Container(
                            child: Column(
                              children: [
                                InputItem(
                                    padding: const EdgeInsets.only(top: 0),
                                    label: dic['toAddress']!,
                                    placeholder: dic['address'],
                                    initialValue: '',
                                    labelAffix: contactName != null
                                        ? Container(
                                            margin: EdgeInsets.only(
                                                left: 8, right: 8),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(2)),
                                            child: Text(
                                              contactName!,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black
                                                      .withOpacity(0.5)),
                                            ),
                                          )
                                        : null,
                                    controller: _toAddressCtrl,
                                    focusNode: addressFocusNode,
                                    suffixIcon: AddressSelectionDropdown(addressList:addressList,onSelect:onSelect),
                                    ),
                                InputItem(
                                    label: dic['amount']!,
                                    initialValue: '',
                                    placeholder: '0',
                                    controller: _amountCtrl,
                                    inputFormatters: [
                                      UI.decimalInputFormatter(decimals)
                                    ],
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
                                    rightWidget: Text(
                                      '${dic['balance']!}:${Fmt.priceFloorBigInt(available, COIN.decimals, lengthMax: COIN.decimals)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0x80000000)),
                                    ),
                                    suffixIcon: GestureDetector(
                                      onTap: _onAllClick,
                                      behavior: HitTestBehavior.opaque,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            dic['allTransfer']!,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .primaryColor),
                                          )
                                        ],
                                      ),
                                    )),
                                InputItem(
                                  label: dic['memo']!,
                                  initialValue: '',
                                  controller: _memoCtrl,
                                ),
                              ],
                            ),
                          ),
                          FeeSelector(
                            fees: fees,
                            onChoose: _onChooseFee,
                            value: currentFee,
                          ),
                          Container(
                            height: 0.5,
                            margin: EdgeInsets.symmetric(
                                horizontal: 0, vertical: 10),
                            decoration: BoxDecoration(color: Color(0x1A000000)),
                          ),
                          AdvancedTransferOptions(
                            feeCtrl: _feeCtrl,
                            nonceCtrl: _nonceCtrl,
                            noncePlaceHolder: store
                                .assets!
                                .accountsInfo[store.wallet!.currentAddress]
                                ?.inferredNonce,
                            cap: fees.cap,
                          )
                        ],
                      ),
                    ),
                    Padding(
                        padding: EdgeInsets.only(
                            top: 15, left: 15, right: 15, bottom: nextBottom)),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 38, vertical: 30),
                      child: NormalButton(
                        color: ColorsUtil.hexColor(0x6D5FFE),
                        text: dic['next']!,
                        submitting: submitting,
                        disabled: submitDisabled,
                        onPressed: _handleSubmit,
                      ),
                    )
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
