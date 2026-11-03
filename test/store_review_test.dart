import 'package:flutter_test/flutter_test.dart';
import 'package:rvaz_android/store_review.dart';
void main(){
 test('Rating and dismissal both leave at least 30 days before another request',()async{
  final data=<String,String>{StoreReviewService.readsKey:'2'};
  var clock=DateTime.utc(2026,11,3),requests=0;
  final service=StoreReviewService(read:(key)async=>data[key],write:(key,value)async{data[key]=value;},available:()async=>true,request:()async{requests++;},openListing:()async{},clock:()=>clock);
  expect(await service.recordArticleRead(const Duration(seconds:30)),isTrue);
  clock=clock.add(const Duration(days:29,hours:23));expect(await service.recordArticleRead(const Duration(seconds:30)),isFalse);expect(requests,1);
  clock=clock.add(const Duration(hours:1));expect(await service.recordArticleRead(const Duration(seconds:30)),isTrue);expect(requests,2);
 });
 test('A store exception still retains the pause across service instances',()async{
  final data=<String,String>{StoreReviewService.readsKey:'3'};var requests=0;
  StoreReviewService create()=>StoreReviewService(read:(key)async=>data[key],write:(key,value)async{data[key]=value;},available:()async=>true,request:()async{requests++;throw Exception('OS dismiss');},openListing:()async{},clock:()=>DateTime.utc(2026,11,3));
  await create().recordArticleRead(const Duration(seconds:30));await create().recordArticleRead(const Duration(seconds:30));expect(requests,1);
 });
 test('Never prompts immediately on launch or after a brief article visit',()async{
  final data=<String,String>{};var requests=0;
  final service=StoreReviewService(read:(key)async=>data[key],write:(key,value)async{data[key]=value;},available:()async=>true,request:()async{requests++;},openListing:()async{});
  await service.recordArticleRead(const Duration(seconds:2));expect(data,isEmpty);
  await service.recordArticleRead(const Duration(seconds:30));await service.recordArticleRead(const Duration(seconds:30));expect(requests,0);
 });
 test('Manual store button opens listing directly and starts the same pause',()async{
  final data=<String,String>{};var opened=false;
  final service=StoreReviewService(read:(key)async=>data[key],write:(key,value)async{data[key]=value;},available:()async=>true,request:()async{},openListing:()async{opened=true;});
  expect(await service.openStore(),isTrue);expect(opened,isTrue);expect(data[StoreReviewService.lastKey],isNotNull);
 });
}
