import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_review/in_app_review.dart';

class StoreReviewService{
 static const cooldown=Duration(days:30);
 static const lastKey='rvaz_store_review_last_request';
 static const readsKey='rvaz_store_review_completed_reads';
 final Future<String?> Function(String) read;
 final Future<void> Function(String,String) write;
 final Future<bool> Function() available;
 final Future<void> Function() request;
 final Future<void> Function() openListing;
 final DateTime Function() now;
 bool working=false;
 StoreReviewService({required this.read,required this.write,required this.available,required this.request,required this.openListing,DateTime Function()? clock}):now=clock??DateTime.now;
 factory StoreReviewService.device(){
  const storage=FlutterSecureStorage();final review=InAppReview.instance;
  return StoreReviewService(read:(key)=>storage.read(key:key),write:(key,value)=>storage.write(key:key,value:value),available:review.isAvailable,request:review.requestReview,openListing:()=>review.openStoreListing(appStoreId:'6817375521'));
 }
 Future<bool> recordArticleRead(Duration elapsed)async{
  if(elapsed<const Duration(seconds:20)||working)return false;
  working=true;
  try{
   final count=(int.tryParse(await read(readsKey)??'0')??0)+1;
   await write(readsKey,'$count');if(count<3)return false;
   final last=int.tryParse(await read(lastKey)??'');
   if(last!=null&&now().toUtc().millisecondsSinceEpoch-last<cooldown.inMilliseconds)return false;
   if(!await available())return false;
   // Neither store reports whether someone rated, dismissed or even saw its
   // dialog. Persist BEFORE calling the API; every outcome receives the pause.
   await write(lastKey,'${now().toUtc().millisecondsSinceEpoch}');
   await request();return true;
  }catch(_){return false;}finally{working=false;}
 }
 Future<bool> openStore()async{
  try{
   await write(lastKey,'${now().toUtc().millisecondsSinceEpoch}');
   await openListing();return true;
  }catch(_){return false;}
 }
}
final storeReviewService=StoreReviewService.device();
