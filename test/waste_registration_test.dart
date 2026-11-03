import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/main.dart';
void main(){
 test('A generic device success never confirms a waste reminder',(){
  expect(wasteRegistrationConfirmed({'ok':true,'registered':true},true),isFalse);
 });
 test('Only the confirmed intended waste preference is accepted',(){
  final receipt={'waste':{'registered':true,'enabled':true,'reminder':'evening_before','timezone':'Europe/Amsterdam'}};
  expect(wasteRegistrationConfirmed(receipt,true),isTrue);
  expect(wasteRegistrationConfirmed(receipt,false),isFalse);
 });
}
