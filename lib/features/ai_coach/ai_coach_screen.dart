import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});
  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  String? _apiKey;
  String _conversationId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadMessages();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _apiKey = prefs.getString('anthropic_api_key'));
  }

  Future<void> _loadMessages() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('ai_messages', where: 'conversation_id = ?', whereArgs: [_conversationId], orderBy: 'created_at ASC');
    setState(() => _messages = rows);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_apiKey == null || _apiKey!.isEmpty) {
      _showApiKeyDialog();
      return;
    }

    final db = await AppDatabase.instance;
    final userMsg = {'id': const Uuid().v4(), 'conversation_id': _conversationId, 'role': 'user', 'content': text, 'created_at': DateTime.now().toIso8601String()};
    await db.insert('ai_messages', userMsg);
    setState(() { _messages = [..._messages, userMsg]; _loading = true; });
    _messageCtrl.clear();
    _scrollToBottom();

    try {
      final context = await _buildHealthContext();
      final history = _messages.map((m) => {'role': m['role'], 'content': m['content'] as String}).toList();

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': _apiKey!,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-opus-4-8',
          'max_tokens': 1024,
          'system': '''You are a personal health AI coach with access to the user's comprehensive health data.
You have deep knowledge of nutrition, fitness, sleep science, longevity, biomarkers, and preventive medicine.
Be specific, evidence-based, and empathetic. Reference the user's actual data when relevant.

USER HEALTH CONTEXT:
$context''',
          'messages': history,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['content'][0]['text'] as String;
        final assistantMsg = {'id': const Uuid().v4(), 'conversation_id': _conversationId, 'role': 'assistant', 'content': reply, 'created_at': DateTime.now().toIso8601String()};
        await db.insert('ai_messages', assistantMsg);
        setState(() { _messages = [..._messages, assistantMsg]; _loading = false; });
        _scrollToBottom();
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  Future<String> _buildHealthContext() async {
    final db = await AppDatabase.instance;
    final buffer = StringBuffer();

    final labs = await db.query('lab_results', orderBy: 'date DESC', limit: 10);
    if (labs.isNotEmpty) {
      buffer.writeln('\nRecent Lab Results:');
      for (final lab in labs) {
        buffer.writeln('- ${lab['test_name']}: ${lab['value']} ${lab['unit']} (${lab['status']}) on ${lab['date']}');
      }
    }

    final sleep = await db.query('sleep_logs', orderBy: 'date DESC', limit: 7);
    if (sleep.isNotEmpty) {
      buffer.writeln('\nRecent Sleep (last 7 nights):');
      for (final s in sleep) {
        buffer.writeln('- ${s['date']}: ${s['total_hours']}h total, ${s['deep_hours']}h deep, ${s['rem_hours']}h REM, HRV: ${s['hrv_avg']}ms, score: ${s['sleep_score']}');
      }
    }

    final wearable = await db.query('wearable_data', orderBy: 'date DESC', limit: 7);
    if (wearable.isNotEmpty) {
      buffer.writeln('\nRecent Wearable Data:');
      for (final w in wearable) {
        buffer.writeln('- ${w['date']}: steps=${w['steps']}, HRV=${w['hrv']}ms, RHR=${w['resting_hr']}bpm, sleep=${w['sleep_hours']}h');
      }
    }

    final diagnoses = await db.query('diagnoses', where: 'status != ?', whereArgs: ['Resolved']);
    if (diagnoses.isNotEmpty) {
      buffer.writeln('\nActive Medical Diagnoses:');
      for (final d in diagnoses) {
        buffer.writeln('- ${d['title']} (${d['status']})');
      }
    }

    final supplements = await db.query('supplements', where: 'active = ?', whereArgs: [1]);
    if (supplements.isNotEmpty) {
      buffer.writeln('\nActive Supplements:');
      for (final s in supplements) {
        buffer.writeln('- ${s['name']} ${s['dose']}${s['unit']} (${s['type']}, ${s['timing']})');
      }
    }

    final bodyComp = await db.query('body_compositions', orderBy: 'date DESC', limit: 1);
    if (bodyComp.isNotEmpty) {
      final bc = bodyComp.first;
      buffer.writeln('\nLatest Body Composition (${bc['date']}): weight=${bc['weight_kg']}kg, body fat=${bc['body_fat_percent']}%, lean mass=${bc['lean_mass_kg']}kg');
    }

    return buffer.isEmpty ? 'No health data available yet.' : buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showApiKeyDialog() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Anthropic API Key', style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter your Anthropic API key to enable the AI Coach. Your key is stored locally only.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextFormField(
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API Key (sk-ant-...)', prefixIcon: Icon(Icons.key, color: AppTheme.textSecondary)),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('anthropic_api_key', ctrl.text);
            setState(() => _apiKey = ctrl.text);
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Analyze my sleep patterns and HRV trends',
      'What does my lab work suggest about my metabolic health?',
      'Optimize my supplement stack for my goals',
      'Create a weekly training plan based on my recovery',
      'What should I focus on to extend my healthspan?',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text('AI Health Coach'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.key), onPressed: _showApiKeyDialog, tooltip: 'Set API Key'),
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () {
              setState(() { _conversationId = const Uuid().v4(); _messages = []; });
            },
            tooltip: 'New conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_messages.isEmpty)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 48),
                          SizedBox(height: 12),
                          Text('Your Personal Health Coach', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                          SizedBox(height: 8),
                          Text('Powered by Claude, with full access to your health vault, labs, sleep, fitness, and supplement data.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Align(alignment: Alignment.centerLeft, child: Text('Suggested questions:', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 12),
                    ...suggestions.map((s) => GestureDetector(
                      onTap: () => _sendMessage(s),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, color: AppTheme.primary, size: 16),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                            const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 12),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(children: [
                        SizedBox(width: 8),
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                        SizedBox(width: 12),
                        Text('Thinking...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ]),
                    );
                  }
                  final msg = _messages[i];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser ? AppTheme.primary : AppTheme.cardBg,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        border: isUser ? null : Border.all(color: AppTheme.border),
                      ),
                      child: Text(msg['content'] as String, style: TextStyle(color: isUser ? Colors.white : AppTheme.textPrimary, fontSize: 14, height: 1.5)),
                    ),
                  );
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask your AI health coach...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _sendMessage(_messageCtrl.text),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
