import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data.dart';

const bg=Color(0xFF10141D), panel=Color(0xFF222D3D), gold=Color(0xFFDCC18A);
const supabaseUrl=String.fromEnvironment('SUPABASE_URL');
const supabaseKey=String.fromEnvironment('SUPABASE_ANON_KEY');
Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 if(supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
  await Supabase.initialize(url:supabaseUrl,anonKey:supabaseKey);
 }
 runApp(const EliteApp());
}
class EliteApp extends StatelessWidget {
 const EliteApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(
  title:'HUAWEI SALES ELITE',debugShowCheckedModeBanner:false,
  theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:gold,brightness:Brightness.dark),cardColor:panel,useMaterial3:true),
  builder:(context,child)=>Directionality(textDirection:TextDirection.rtl,child:child!),
  home:const RootPage(),
 );
}
class RootPage extends StatefulWidget { const RootPage({super.key}); @override State<RootPage> createState()=>_RootState(); }
class _RootState extends State<RootPage> {
 SharedPreferences? prefs;
 String name='',store='';
 bool loading=true, online=false;
 int startDay=0;
 Set<String> completed={}; Set<int> lessonDone={};
 SupabaseClient? get api=>supabaseUrl.isEmpty?null:Supabase.instance.client;
 @override void initState(){super.initState();init();}
 Future<void> init() async {
  prefs=await SharedPreferences.getInstance();
  name=prefs!.getString('name')??'';store=prefs!.getString('store')??'';
  startDay=prefs!.getInt('startDay')??0;
  completed=(prefs!.getStringList('tasks')??[]).toSet();
  lessonDone=(prefs!.getStringList('lessons')??[]).map(int.parse).toSet();
  if(api!=null){try{if(api!.auth.currentUser==null) await api!.auth.signInAnonymously(); online=true; await sync();}catch(_){online=false;}}
  if(mounted)setState(()=>loading=false);
 }
 int get today=>DateTime.now().toUtc().add(const Duration(hours:3)).millisecondsSinceEpoch~/86400000;
 int get day=>startDay==0?1:((today-startDay).clamp(0,29)+1);
 int get points=>completed.length*30+lessonDone.length*50;
 Future<void> register(String n,String s) async {
  name=n.trim();store=s.trim();startDay=today;
  await prefs!.setString('name',name);await prefs!.setString('store',store);await prefs!.setInt('startDay',startDay);
  if(api!=null){try{await api!.from('employees').upsert({'id':api!.auth.currentUser!.id,'full_name':name,'store_name':store,'start_day':startDay});online=true;}catch(_){online=false;}}
  if(mounted)setState((){});
 }
 Future<void> sync() async {
  if(api==null||name.isEmpty)return;
  try{
   final id=api!.auth.currentUser!.id;
   await api!.from('employees').upsert({'id':id,'full_name':name,'store_name':store,'start_day':startDay});
   for(final key in completed){final p=key.split(':');await api!.from('task_completions').upsert({'employee_id':id,'day_number':int.parse(p[0]),'task_number':int.parse(p[1])});}
   for(final l in lessonDone){await api!.from('lesson_completions').upsert({'employee_id':id,'lesson_number':l});}
   online=true;
  }catch(_){online=false;}
 }
 Future<void> taskToggle(int task) async {
  final key='$day:$task';
  setState((){if(!completed.add(key))completed.remove(key);});
  await prefs!.setStringList('tasks',completed.toList());
  if(api!=null){try{final id=api!.auth.currentUser!.id;
   if(completed.contains(key)){await api!.from('task_completions').upsert({'employee_id':id,'day_number':day,'task_number':task});}
   else {await api!.from('task_completions').delete().eq('employee_id',id).eq('day_number',day).eq('task_number',task);}
   online=true;
  }catch(_){online=false;}}
  if(mounted)setState((){});
 }
 Future<void> lessonToggle(int l) async {
  setState((){if(!lessonDone.add(l))lessonDone.remove(l);});
  await prefs!.setStringList('lessons',lessonDone.map((e)=>'$e').toList());
  if(api!=null){try{final id=api!.auth.currentUser!.id;
   if(lessonDone.contains(l)){await api!.from('lesson_completions').upsert({'employee_id':id,'lesson_number':l});}
   else {await api!.from('lesson_completions').delete().eq('employee_id',id).eq('lesson_number',l);}
   online=true;
  }catch(_){online=false;}}
  if(mounted)setState((){});
 }
 @override Widget build(BuildContext context){
  if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
  return Scaffold(appBar:AppBar(backgroundColor:bg,title:const Text('HUAWEI SALES ELITE',style:TextStyle(color:gold,fontSize:17,fontWeight:FontWeight.bold)),actions:[IconButton(tooltip:'لوحة المسؤول',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AdminPage(api:api))),icon:const Icon(Icons.admin_panel_settings_outlined,color:gold))]),
   body:name.isEmpty?RegisterPage(onRegister:register):home());
 }
 Widget home(){final c=challenges[day-1];final done=List.generate(3,(i)=>completed.contains('$day:$i')).where((e)=>e).length;
  return ListView(padding:const EdgeInsets.all(16),children:[
   const Center(child:Icon(Icons.workspace_premium_rounded,color:gold,size:45)),
   const Center(child:Text('Sales Elite',style:TextStyle(fontWeight:FontWeight.bold,fontSize:20))),
   const Center(child:Text('Learn · Apply · Master',style:TextStyle(color:gold))),
   const SizedBox(height:22),Text('أهلًا، $name 👋',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),Text('المعرض: $store',style:const TextStyle(color:Colors.white70)),
   const SizedBox(height:8),Text(online?'الإنجازات متزامنة مع لوحة المسؤول':'الإنجازات محفوظة على هذا الجهاز؛ المزامنة غير متاحة',style:TextStyle(color:online?Colors.greenAccent:Colors.orangeAccent,fontSize:12)),
   const SizedBox(height:16),Row(children:[Expanded(child:metric('نقاطك','$points',Icons.bolt)),const SizedBox(width:8),Expanded(child:metric('المهام','${completed.length}/90',Icons.check_circle_outline)),const SizedBox(width:8),Expanded(child:metric('الدروس','${lessonDone.length}/12',Icons.menu_book))]),
   const SizedBox(height:20),section('🔥 تحدي اليوم $day من ٣٠'),
   Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(c.title,style:const TextStyle(color:gold,fontWeight:FontWeight.bold,fontSize:20)),const SizedBox(height:8),LinearProgressIndicator(value:done/3,color:gold,backgroundColor:Colors.white12),const SizedBox(height:10),...List.generate(3,(i)=>CheckboxListTile(activeColor:gold,checkColor:bg,contentPadding:EdgeInsets.zero,value:completed.contains('$day:$i'),onChanged:(_)=>taskToggle(i),title:Text(c.tasks[i]),subtitle:const Text('٣٠ نقطة بعد الإنجاز',style:TextStyle(color:gold,fontSize:11)))),if(done==3)const Text('🎉 أحسنت! أنجزت مهام اليوم.',style:TextStyle(color:gold))]))),
   const SizedBox(height:20),section('📚 أكاديمية مهارات البيع'),const Text('دروس عملية يمكنك الرجوع إليها في أي وقت',style:TextStyle(color:Colors.white70)),const SizedBox(height:8),
   ...List.generate(lessons.length,(i)=>Card(child:ListTile(leading:Icon(lessonDone.contains(i)?Icons.verified:Icons.auto_stories,color:gold),title:Text(lessons[i].title),subtitle:Text(lessons[i].goal,maxLines:1,overflow:TextOverflow.ellipsis),trailing:const Icon(Icons.chevron_left),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>LessonPage(lesson:lessons[i],done:lessonDone.contains(i),onToggle:()=>lessonToggle(i)))).then((_)=>setState((){}))))),
   const SizedBox(height:24),const Center(child:Text('كل يوم خطوة جديدة نحو الاحتراف ✨',style:TextStyle(color:gold))),const SizedBox(height:30),
  ]);
 }
 Widget metric(String label,String value,IconData icon)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(14)),child:Column(children:[Icon(icon,color:gold),const SizedBox(height:8),Text(value,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),Text(label,style:const TextStyle(fontSize:11,color:Colors.white70))]));
 Widget section(String s)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Text(s,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:gold)));
}
class RegisterPage extends StatefulWidget {final Future<void> Function(String,String) onRegister;const RegisterPage({super.key,required this.onRegister});@override State<RegisterPage> createState()=>_RegisterState();}
class _RegisterState extends State<RegisterPage>{final n=TextEditingController(),s=TextEditingController();bool busy=false;
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(24),children:[const SizedBox(height:30),const Center(child:Icon(Icons.workspace_premium,color:gold,size:60)),const Center(child:Text('Sales Elite',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold))),const Center(child:Text('Learn · Apply · Master',style:TextStyle(color:gold))),const SizedBox(height:40),const Text('مرحبًا بك في رحلة الاحتراف',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),const SizedBox(height:12),const Text('سجّل بياناتك مرة واحدة للبدء.'),const SizedBox(height:22),TextField(controller:n,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'اسم الموظف',border:OutlineInputBorder())),const SizedBox(height:16),TextField(controller:s,decoration:const InputDecoration(labelText:'اسم المعرض',border:OutlineInputBorder())),const SizedBox(height:24),FilledButton(onPressed:busy?null:()async{if(n.text.trim().isEmpty||s.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أدخل اسم الموظف واسم المعرض')));return;}setState(()=>busy=true);await widget.onRegister(n.text,s.text);if(mounted)setState(()=>busy=false);},child:Text(busy?'جارٍ التسجيل...':'ابدأ رحلتك'))]);}
}
class LessonPage extends StatefulWidget {final Lesson lesson;final bool done;final Future<void> Function() onToggle;const LessonPage({super.key,required this.lesson,required this.done,required this.onToggle});@override State<LessonPage> createState()=>_LessonState();}
class _LessonState extends State<LessonPage>{late bool done;
 @override void initState(){super.initState();done=widget.done;}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.lesson.title)),body:ListView(padding:const EdgeInsets.all(18),children:[block('الهدف',widget.lesson.goal),block('كيف تطبق المهارة؟',widget.lesson.steps),block('مثال حوار مع العميل',widget.lesson.script),block('اعتراض شائع',widget.lesson.objection),block('الرد المقترح',widget.lesson.response),block('تدريب عملي',widget.lesson.practice),const SizedBox(height:12),FilledButton.icon(icon:Icon(done?Icons.check_circle:Icons.verified_outlined),label:Text(done?'إلغاء إكمال الدرس':'أكملت الدرس · ٥٠ نقطة'),onPressed:()async{await widget.onToggle();if(mounted)setState(()=>done=!done);})]));
 Widget block(String title,String content)=>Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:gold,fontWeight:FontWeight.bold,fontSize:17)),const SizedBox(height:10),Text(content,style:const TextStyle(height:1.7))])));
}
class AdminPage extends StatefulWidget {final SupabaseClient? api;const AdminPage({super.key,required this.api});@override State<AdminPage> createState()=>_AdminState();}
class _AdminState extends State<AdminPage>{final pass=TextEditingController();String? token,error;bool busy=false;List<dynamic> staff=[];
 Future<void> login()async{if(widget.api==null){setState(()=>error='يجب إعداد قاعدة البيانات أولًا.');return;}setState((){busy=true;error=null;});try{final result=await widget.api!.rpc('admin_login',params:{'p_password':pass.text});if(result==null)throw Exception('رمز غير صحيح');token=result.toString();pass.clear();await refresh();}catch(_){error='تعذر الدخول. تحقق من الرمز واتصال قاعدة البيانات.';}if(mounted)setState(()=>busy=false);}
 Future<void> refresh()async{try{final r=await widget.api!.rpc('admin_dashboard',params:{'p_token':token});staff=(r as List<dynamic>);error=null;}catch(_){error='تعذر تحميل النتائج. أعد تسجيل الدخول.';token=null;}if(mounted)setState((){});}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('لوحة المسؤول')),body:token==null?ListView(padding:const EdgeInsets.all(24),children:[const Icon(Icons.admin_panel_settings,color:gold,size:55),const SizedBox(height:16),const Text('دخول المسؤول',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),const SizedBox(height:14),TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'الرقم السري',border:OutlineInputBorder())),const SizedBox(height:16),FilledButton(onPressed:busy?null:login,child:const Text('دخول')),if(error!=null)Text(error!,style:const TextStyle(color:Colors.orangeAccent))]):RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.all(16),children:[const Text('إنجازات الموظفين',style:TextStyle(color:gold,fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:12),Text('عدد الموظفين: ${staff.length}'),Text('مجموع النقاط: ${staff.fold<int>(0,(a,b)=>a+((b['points'] as num?)?.toInt()??0))}'),const SizedBox(height:14),...staff.map((e)=>Card(child:ListTile(leading:const Icon(Icons.emoji_events,color:gold),title:Text('${e['full_name']}'),subtitle:Text('المعرض: ${e['store_name']}\nالمهام: ${e['task_count']}/90 · الدروس: ${e['lesson_count']}/12'),trailing:Text('${e['points']} نقطة',style:const TextStyle(color:gold))))),if(staff.isEmpty)const Text('لم يسجّل أي موظف بعد.')])));
}
