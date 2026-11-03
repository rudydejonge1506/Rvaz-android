part of 'main.dart';

/// A successful general push registration does not prove the waste reminder
/// was saved: older API versions silently ignored the waste payload.
bool wasteRegistrationConfirmed(dynamic response,bool enabled){
 if(response is! Map||response['waste'] is! Map)return false;
 final waste=response['waste'] as Map;
 return waste['registered']==true&&waste['enabled']==enabled&&waste['reminder']=='evening_before'&&waste['timezone']=='Europe/Amsterdam';
}
