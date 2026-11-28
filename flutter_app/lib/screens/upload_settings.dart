import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../upload_service.dart';

class UploadSettingsPage extends StatefulWidget {
  const UploadSettingsPage({super.key});

  @override
  State<UploadSettingsPage> createState() => _UploadSettingsPageState();
}

class _UploadSettingsPageState extends State<UploadSettingsPage> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  bool _enabled = true;
  bool _hasToken = false;
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AppStore.instance.load();
    final url = await VideoUploadService.readServerUrl();
    final token = await VideoUploadService.readToken();
    final enabled = await VideoUploadService.isEnabled();
    if (!mounted) return;
    setState(() {
      _url.text = url;
      _hasToken = (token ?? '').isNotEmpty;
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final serverUrl = _url.text.trim();
    if (serverUrl.isNotEmpty) {
      final uri = Uri.tryParse(serverUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        setState(() => _message = '伺服器網址必須使用有效的 HTTPS 網址。');
        return;
      }
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    final token = _token.text.trim().isEmpty ? null : _token.text.trim();
    await VideoUploadService.saveConfig(serverUrl: _url.text, token: token, enabled: _enabled);
    _token.clear();
    _hasToken = (await VideoUploadService.readToken() ?? '').isNotEmpty;
    if (_enabled && _url.text.trim().isNotEmpty && _hasToken) {
      await VideoUploadService.retryFailedVideos();
      await VideoUploadService.enqueue();
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = '已儲存。影片只會在 Wi-Fi 等非計量網路可用時背景上傳；行動數據不會觸發上傳。';
    });
  }

  Future<void> _schedulePending() async {
    final url = await VideoUploadService.readServerUrl();
    final token = await VideoUploadService.readToken();
    if (url.isEmpty || (token ?? '').isEmpty) {
      if (!mounted) return;
      setState(() => _message = '請先設定 HTTPS 伺服器網址和上傳金鑰。');
      return;
    }
    await VideoUploadService.retryFailedVideos();
    await VideoUploadService.enqueue();
    if (!mounted) return;
    setState(() => _message = '已排程待上傳影片；裝置連上 Wi-Fi 等非計量網路後會開始傳送。');
  }

  Future<void> _clearToken() async {
    await VideoUploadService.saveConfig(serverUrl: _url.text, token: '', enabled: _enabled);
    if (!mounted) return;
    setState(() {
      _hasToken = false;
      _message = '已清除伺服器金鑰。';
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pending = AppStore.instance.media.where((m) => m.kind == MediaKind.video && (m.uploadState == 'pending' || m.uploadState == 'uploading')).length;
    final failed = AppStore.instance.media.where((m) => m.kind == MediaKind.video && m.uploadState == 'failed').length;
    final uploaded = AppStore.instance.media.where((m) => m.kind == MediaKind.video && m.uploadState == 'uploaded').length;
    return Scaffold(
      appBar: AppBar(title: const Text('課程影片上傳')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('影片會保留在手機。開啟自動上傳後，新錄好的影片會在 Wi-Fi 等非計量網路可用時排程上傳；不使用行動網路。',
            style: TextStyle(color: AppColors.muted, height: 1.5)),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自動上傳（僅非計量網路）'),
          subtitle: const Text('關閉時只保存在手機，不會排程傳送'),
          value: _enabled,
          activeColor: AppColors.chalkYellowBright,
          onChanged: (value) => setState(() => _enabled = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: '伺服器 HTTPS 網址',
            hintText: 'https://upload.example.com',
            helperText: 'Linux 接收服務架好後再填入網域網址。',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _token,
          obscureText: true,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: '伺服器上傳金鑰',
            hintText: _hasToken ? '已設定；留白會保留原金鑰' : '尚未設定',
            helperText: '金鑰會加密保存在手機。',
          ),
        ),
        if (_hasToken)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _clearToken, child: const Text('清除已儲存的金鑰')),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? '儲存中…' : '儲存設定'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _schedulePending,
          icon: const Icon(Icons.sync),
          label: Text('排程／重試影片（${pending + failed} 段）'),
        ),
        const SizedBox(height: 12),
        Text('已上傳 $uploaded 段・待上傳 $pending 段・失敗 $failed 段', style: const TextStyle(color: AppColors.muted)),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!, style: const TextStyle(color: AppColors.chalkYellowBright)),
        ],
        const SizedBox(height: 20),
        const Text('目前 Linux 伺服器尚未架設，影片會先留在手機。伺服器網址與金鑰準備好後，填入上方即可啟用。',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
      ]),
    );
  }
}
