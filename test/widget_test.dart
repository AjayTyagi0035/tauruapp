import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tauruapp/main.dart';
import 'package:tauruapp/models/survey_submission.dart';

void main() {
  testWidgets('Shows login screen when no user is saved', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TauruApp());
    await tester.pumpAndSettle();

    expect(find.text('Tauru App'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  test('SurveySubmission JSON keys match table columns', () {
    final json = const SurveySubmission(
      widthofRoadInFront: '3 - 9 m',
      typeofconstruction: 'RCC',
      useofhouse: 'Mixed',
      membersInHouse: 4,
    ).toJson();

    expect(json['WidthofRoadInFront'], '3 - 9 m');
    expect(json['Typeofconstruction'], 'RCC');
    expect(json['Useofhouse'], 'Mixed');
    expect(json['membersInHouse'], 4);
    expect(json.containsKey('id'), isFalse);

    final roundTrip = SurveySubmission.fromJson(json).toJson();
    expect(roundTrip, json);
  });
}
