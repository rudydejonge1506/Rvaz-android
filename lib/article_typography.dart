part of 'main.dart';

/// Shared with the website's krant.css and final article heading rules.
/// Fonts are bundled, so Android and iOS render the same editorial typefaces.
abstract final class RvazTypography {
 static const heading=TextStyle(fontFamily:'Dosis',fontWeight:FontWeight.w600,color:Color(0xff073b66),height:1.25,letterSpacing:0);
 static const body=TextStyle(fontFamily:'OpenSans',fontSize:16,fontWeight:FontWeight.w400,color:Color(0xff343d43),height:1.7);
 static TextStyle articleTitle(double width)=>heading.copyWith(fontSize:width<=760?29:32,height:1.2);
 static Map<String,Style> articleStyles(double width){
  final result=<String,Style>{
   'body':Style(fontFamily:'OpenSans',fontSize:FontSize(16),fontWeight:FontWeight.w400,lineHeight:const LineHeight(1.7),color:const Color(0xff343d43),margin:Margins.zero,padding:HtmlPaddings.zero),
   'p':Style(margin:Margins.only(top:0,bottom:12)),
   'figure':Style(margin:Margins.zero),
   'a':Style(color:const Color(0xff073b66),textDecoration:TextDecoration.underline),
  };
  for(final entry in {'h1':width<=760?29.0:32.0,'h2':27.0,'h3':24.0,'h4':21.0,'h5':21.0,'h6':21.0}.entries){
   result[entry.key]=Style(fontFamily:'Dosis',fontSize:FontSize(entry.value),fontWeight:FontWeight.w600,lineHeight:const LineHeight(1.3),letterSpacing:0,color:const Color(0xff073b66),margin:Margins.only(top:32,bottom:18));
   // WordPress often wraps a heading in strong/b/span/font. Those inline
   // elements must inherit the heading style, while bold body text stays bold.
   result['${entry.key} *']=Style(fontFamily:'Dosis',fontSize:FontSize(entry.value),fontWeight:FontWeight.w600,lineHeight:const LineHeight(1.3),letterSpacing:0,color:const Color(0xff073b66));
  }
  return result;
 }
}

class RvazArticleHtml extends StatelessWidget {
 final String data;
 final bool prepared;
 const RvazArticleHtml({super.key,required this.data,this.prepared=false});
 @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,constraints)=>Html(
  data:prepared?data:cleanArticleHtml(data),style:RvazTypography.articleStyles(MediaQuery.sizeOf(context).width),
  onLinkTap:(url,attributes,element)async{
   if(url==null||url.trim().isEmpty)return;
   final uri=Uri.tryParse(url.trim());
   if(uri!=null&&['https','http','mailto','tel'].contains(uri.scheme))await launchUrl(uri,mode:LaunchMode.externalApplication);
  },
 ));
}
