import 'package:image/image.dart';
import 'package:test/test.dart';

import 'package:esc_pos_dart/esc_pos_dart.dart';

void main() {
  group('PrinterDocument', () {
    test('Tests not implemented', () {
      final image = Image(width: 1, height: 1);
      image.setPixelRgba(0, 0, 255, 0, 0, 255);
      var doc = PrinterDocument();

      doc.addText(text: 'Hello', style: PrinterCommandStyle(align: 'left'));

      doc.addText(
          text: 'World!',
          style: PrinterCommandStyle(align: 'right', bold: true));

      doc.addHR();

      doc.addImage(image);

      doc.addCut();

      expect(
          doc.toJson(),
          equals(
            {
              'commands': [
                {'type': 'text', 'text': 'Hello'},
                {
                  'type': 'text',
                  'text': 'World!',
                  'style': {'bold': true, 'align': 'right'}
                },
                {'type': 'hr'},
                {
                  'type': 'image',
                  'width': 1,
                  'height': 1,
                  'align': 'center',
                  'image':
                      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4AWP5z8DwHwAFFAIDECIziQAAAABJRU5ErkJggg=='
                },
                {'type': 'cut', 'full': true}
              ]
            },
          ));
    });
  });
}
