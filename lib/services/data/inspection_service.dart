import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/services/core/firebase_service.dart';

class InspectionService {
  final FirebaseService _firebase = FirebaseService();

  Future<Inspection?> getInspection(String inspectionId) async {
    final doc = await _firebase.firestore.collection('inspections').doc(inspectionId).get();
    
    if (!doc.exists) return null;
    
    return Inspection.fromMap({
      'id': doc.id,
      ...doc.data() ?? {},
    });
  }

  Future<void> saveInspection(Inspection inspection) async {
    final data = inspection.toMap();
    data.remove('id');
    await _firebase.firestore
        .collection('inspections')
        .doc(inspection.id)
        .set(data, SetOptions(merge: true));
  }
}