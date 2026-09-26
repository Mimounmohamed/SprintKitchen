import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_d/kds_screen.dart';

void main() {
  group('KDS Models Tests', () {
    test('KdsItem.fromJson parses item with customizations and removals', () {
      final json = {
        'productName': 'Menu B8',
        'quantity': 2,
        'customizations': [
          {
            'groupName': 'Cuisson de la viande',
            'selectedOptions': [
              {'label': 'A point', 'priceModifier': 0}
            ]
          }
        ],
        'removedIngredients': ['Oignons', 'Sans Tomate'],
        'notes': 'Bien chaud',
      };

      final item = KdsItem.fromJson(json);

      expect(item.name, 'Menu B8');
      expect(item.qty, '2×');
      expect(item.subLines, contains('Cuisson de la viande: A point'));
      expect(item.subLines, contains('Sans Oignons'));
      expect(item.subLines, contains('Sans Tomate'));
      expect(item.subLines, contains('Bien chaud'));
    });

    test('KitchenOrder.fromJson parses active order correctly', () {
      final json = {
        '_id': '6ab8195158d5958a98832b3a',
        'ticketNumber': '0000003',
        'orderType': 'sur_place',
        'status': 'en_attente',
        'kdsStatus': 'pending',
        'items': [
          {
            'productName': 'Burger Classic',
            'quantity': 1,
            'customizations': [],
            'removedIngredients': [],
          }
        ],
        'createdAt': '2026-09-26T19:12:45.230Z',
      };

      final order = KitchenOrder.fromJson(json);

      expect(order.id, '6ab8195158d5958a98832b3a');
      expect(order.ticketNumber, '#0000003');
      expect(order.mode, OrderMode.surPlace);
      expect(order.status, OrderStatus.attente);
      expect(order.items.length, 1);
      expect(order.items.first.name, 'Burger Classic');
    });

    test('KitchenOrder.fromJson handles in_progress, ready, and served states', () {
      final orderPrep = KitchenOrder.fromJson({
        '_id': '1',
        'ticketNumber': '001',
        'orderType': 'a_emporter',
        'kdsStatus': 'in_progress',
        'items': [],
      });
      expect(orderPrep.status, OrderStatus.preparation);
      expect(orderPrep.mode, OrderMode.emporter);

      final orderReady = KitchenOrder.fromJson({
        '_id': '2',
        'ticketNumber': '002',
        'orderType': 'livraison',
        'kdsStatus': 'ready',
        'items': [],
      });
      expect(orderReady.status, OrderStatus.pret);
      expect(orderReady.note, 'PRÊT');
      expect(orderReady.mode, OrderMode.livraison);
    });
  });
}
