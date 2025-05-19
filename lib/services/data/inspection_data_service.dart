import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/inspection.dart';

class InspectionDataService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<Inspection?> getInspection(String inspectionId) async {
    final docSnapshot =
        await firestore.collection('inspections').doc(inspectionId).get();

    if (!docSnapshot.exists) {
      return null;
    }

    return Inspection.fromMap({
      'id': docSnapshot.id,
      ...docSnapshot.data() ?? {},
    });
  }

  Future<void> saveInspection(Inspection inspection) async {
    await firestore.collection('inspections').doc(inspection.id).set(
          inspection.toMap()..remove('id'),
          SetOptions(merge: true),
        );
  }
}
