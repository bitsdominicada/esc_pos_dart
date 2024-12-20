/*
 * esc_pos_printer
 * Created by Andrey Ushakov
 * Improved by Graciliano M. Passos.
 *
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:image/image.dart';

import '../utils/barcode.dart';
import '../utils/capability_profile.dart';
import '../utils/enums.dart';
import '../utils/generator.dart';
import '../utils/pos_column.dart';
import '../utils/pos_styles.dart';
import '../utils/qrcode.dart';
import 'enums.dart';

/// Network Printer
class NetworkPrinter {
  final PaperSize _paperSize;
  final CapabilityProfile _profile;

  late final Generator _generator;

  NetworkPrinter(this._paperSize, this._profile, {int spaceBetweenRows = 5})
      : _generator =
            Generator(_paperSize, _profile, spaceBetweenRows: spaceBetweenRows);

  PaperSize get paperSize => _paperSize;

  CapabilityProfile get profile => _profile;

  String? _host;

  String? get host => _host;

  int? _port;

  int? get port => _port;

  late Socket _socket;
  final List<int> _inputBytes = <int>[];

  bool _connected = false;

  bool get isConnected => _connected;

  Future<PosPrintResult> connect(String host,
      {int port = 91000, Duration timeout = const Duration(seconds: 5)}) async {
    _host = host;
    _port = port;

    return await ensureConnected(timeout: timeout);
  }

  Future<PosPrintResult> ensureConnected(
      {Duration timeout = const Duration(seconds: 5)}) async {
    if (_connected) {
      return PosPrintResult.success;
    }

    try {
      var host = _host;
      var port = _port;

      if (host == null || port == null) {
        throw StateError("Call `connect` first to define `host` and `port`!");
      }

      _socket = await Socket.connect(host, port, timeout: timeout);
      _connected = true;

      _socket.listen(_addInputBytes);
      _socket.add(_generator.reset());

      return Future<PosPrintResult>.value(PosPrintResult.success);
    } catch (e) {
      return Future<PosPrintResult>.value(PosPrintResult.timeout);
    }
  }

  /// Closes the printer [Socket] and disposes any received byte in buffer.
  /// [delayMs]: milliseconds to wait after destroying the socket
  Future<void> disconnect({int? delayMs}) async {
    if (delayMs != null && delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    _connected = false;
    _socket.destroy();
    _disposeInputBytes();
  }

  void _disposeInputBytes() {
    _inputBytes.clear();
  }

  void _addInputBytes(Uint8List bs) {
    _inputBytes.addAll(bs);
    _notifyInputBytes();
  }

  void _notifyInputBytes() {
    var completer = _waitingBytes;
    if (completer != null && !completer.isCompleted) {
      _waitingBytes = null;
      completer.complete(true);
    }
  }

  Completer<bool>? _waitingBytes;

  Future<bool> _waitInputByte() {
    var completer = _waitingBytes;
    if (completer != null) {
      return completer.future;
    }

    completer = _waitingBytes = Completer<bool>();

    var future = completer.future.then((ok) {
      if (identical(_waitingBytes, completer)) {
        _waitingBytes = null;
      }
      return ok;
    });

    return future;
  }

  // ************************ Printer Commands ************************
  void reset() {
    _socket.add(_generator.reset());
  }

  void endJob() {
    _socket.add(_generator.endJob());
  }

  void text(
    String text, {
    PosStyles styles = const PosStyles(),
    int linesAfter = 0,
    bool containsChinese = false,
    int? maxCharsPerLine,
  }) {
    _socket.add(_generator.text(text,
        styles: styles,
        linesAfter: linesAfter,
        containsChinese: containsChinese,
        maxCharsPerLine: maxCharsPerLine));
  }

  void setGlobalCodeTable(String codeTable) {
    _socket.add(_generator.setGlobalCodeTable(codeTable));
  }

  void setGlobalFont(PosFontType font, {int? maxCharsPerLine}) {
    _socket
        .add(_generator.setGlobalFont(font, maxCharsPerLine: maxCharsPerLine));
  }

  void setStyles(PosStyles styles, {bool isKanji = false}) {
    _socket.add(_generator.setStyles(styles, isKanji: isKanji));
  }

  void rawBytes(List<int> cmd, {bool isKanji = false}) {
    _socket.add(_generator.rawBytes(cmd, isKanji: isKanji));
  }

  void emptyLines(int n) {
    _socket.add(_generator.emptyLines(n));
  }

  void feed(int n) {
    _socket.add(_generator.feed(n));
  }

  void cut({PosCutMode mode = PosCutMode.full}) {
    _socket.add(_generator.cut(mode: mode));
  }

  void printCodeTable({String? codeTable}) {
    _socket.add(_generator.printCodeTable(codeTable: codeTable));
  }

  void beep({int n = 3, PosBeepDuration duration = PosBeepDuration.beep450ms}) {
    _socket.add(_generator.beep(n: n, duration: duration));
  }

  void reverseFeed(int n) {
    _socket.add(_generator.reverseFeed(n));
  }

  void row(List<PosColumn> cols) {
    _socket.add(_generator.row(cols));
  }

  void image(Image imgSrc, {PosAlign align = PosAlign.center}) {
    _socket.add(_generator.image(imgSrc, align: align));
  }

  void imageRaster(
    Image image, {
    PosAlign align = PosAlign.center,
    bool highDensityHorizontal = true,
    bool highDensityVertical = true,
    PosImageFn imageFn = PosImageFn.bitImageRaster,
  }) {
    _socket.add(_generator.imageRaster(
      image,
      align: align,
      highDensityHorizontal: highDensityHorizontal,
      highDensityVertical: highDensityVertical,
      imageFn: imageFn,
    ));
  }

  void barcode(
    Barcode barcode, {
    int? width,
    int? height,
    BarcodeFont? font,
    BarcodeText textPos = BarcodeText.below,
    PosAlign align = PosAlign.center,
  }) {
    _socket.add(_generator.barcode(
      barcode,
      width: width,
      height: height,
      font: font,
      textPos: textPos,
      align: align,
    ));
  }

  void qrcode(
    String text, {
    PosAlign align = PosAlign.center,
    QRSize size = QRSize.size4,
    QRCorrection cor = QRCorrection.L,
  }) {
    _socket.add(_generator.qrcode(text, align: align, size: size, cor: cor));
  }

  void drawer({PosDrawer pin = PosDrawer.pin2}) {
    _socket.add(_generator.drawer(pin: pin));
  }

  void hr({String ch = '-', int? len, int linesAfter = 0}) {
    _socket.add(_generator.hr(ch: ch, linesAfter: linesAfter));
  }

  void textEncoded(
    Uint8List textBytes, {
    PosStyles styles = const PosStyles(),
    int linesAfter = 0,
    int? maxCharsPerLine,
  }) {
    _socket.add(_generator.textEncoded(
      textBytes,
      styles: styles,
      linesAfter: linesAfter,
      maxCharsPerLine: maxCharsPerLine,
    ));
  }

  Future<int?> transmissionOfStatus({int n = 1}) async {
    var waitFuture = _waitInputByte();
    _socket.add(_generator.transmissionOfStatus(n: n));
    await waitFuture;

    var status = _inputBytes.lastOrNull;
    if (status != null) {
      // Remove reserved bits:
      status = status & 0x0F;
    }
    return status;
  }

// ************************ (end) Printer Commands ************************
}
