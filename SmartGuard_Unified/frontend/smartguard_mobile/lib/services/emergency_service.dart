import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class EmergencyService {
  static const String _storageKey = 'smartguard_emergency_contacts';

  static Future<List<EmergencyContactModel>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((e) => EmergencyContactModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // Default emergency family members (matching user mockup)
    final defaultList = [
      EmergencyContactModel(
        id: 'ec-1',
        name: 'Quỳnh Hương',
        phone: '0988 123 456',
        relationship: 'Chủ nhà',
        isCallAlert: true,
        isSmsAlert: true,
        email: 'quynhhuong@gmail.com',
      ),
      EmergencyContactModel(
        id: 'ec-2',
        name: 'Minh Trí',
        phone: '0977 654 321',
        relationship: 'Bố',
        isCallAlert: true,
        isSmsAlert: true,
      ),
      EmergencyContactModel(
        id: 'ec-3',
        name: 'Bảo Anh',
        phone: '0912 888 999',
        relationship: 'Vợ',
        isCallAlert: true,
        isSmsAlert: true,
      ),
    ];

    await saveContacts(defaultList);
    return defaultList;
  }

  static Future<void> saveContacts(List<EmergencyContactModel> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = contacts.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  static Future<void> addContact(EmergencyContactModel contact) async {
    final current = await getContacts();
    current.add(contact);
    await saveContacts(current);
  }

  static Future<void> updateContact(EmergencyContactModel updated) async {
    final current = await getContacts();
    final index = current.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      current[index] = updated;
      await saveContacts(current);
    }
  }

  static Future<void> deleteContact(String id) async {
    final current = await getContacts();
    current.removeWhere((c) => c.id == id);
    await saveContacts(current);
  }

  // Trigger emergency dispatch (SMS & Call simulation for intrusions)
  // Returns a map with: contacts (List), summary (String), callList (List), smsList (List)
  static Future<Map<String, dynamic>> dispatchEmergencyAlert({
    required String reason,
    String location = 'Không xác định',
  }) async {
    final contacts = await getContacts();
    final callList = <EmergencyContactModel>[];
    final smsList = <EmergencyContactModel>[];
    final notified = <String>[];

    for (final contact in contacts) {
      if (contact.isCallAlert) {
        callList.add(contact);
        notified.add('📞 Gọi ${contact.name} (${contact.phone})');
      }
      if (contact.isSmsAlert) {
        smsList.add(contact);
        notified.add('💬 SMS → ${contact.name} (${contact.phone})');
      }
    }

    final summary = notified.isEmpty
        ? 'Không có liên hệ khẩn cấp nào được cấu hình.'
        : 'Đã thông báo ${callList.length} cuộc gọi & ${smsList.length} SMS.\n${notified.join('\n')}';

    return {
      'contacts': contacts,
      'callList': callList,
      'smsList': smsList,
      'notified': notified,
      'summary': summary,
      'reason': reason,
      'location': location,
    };
  }
}

