#!/usr/bin/env python3
"""Generate mock UI captures + framed App Store banners for Screenshot & Clipboard Buddy."""

from __future__ import annotations

import math
from pathlib import Path
from typing import Optional

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

try:
    import arabic_reshaper
    from bidi.algorithm import get_display
except ImportError:  # pragma: no cover
    arabic_reshaper = None
    get_display = None

ROOT = Path(__file__).resolve().parents[3]
LANGS = ["en", "nl", "pt", "es", "fr", "it", "ar", "zh", "ru", "ja"]

BANNER_W, BANNER_H = 1280, 800
RAW_W, RAW_H = 980, 620

# Icon-aligned brand colors
SHOT_COLORS = {
    "top": (255, 122, 61),
    "mid": (255, 179, 71),
    "bot": (255, 212, 168),
    "accent": (232, 93, 34),
    "ui_bg": (250, 248, 245),
    "sidebar": (245, 240, 234),
    "chip": (255, 214, 170),
}
CLIP_COLORS = {
    "top": (52, 211, 153),
    "mid": (16, 185, 129),
    "bot": (163, 230, 53),
    "accent": (5, 150, 105),
    "ui_bg": (246, 250, 247),
    "sidebar": (236, 245, 239),
    "chip": (167, 243, 208),
}

FONT_LATIN = "/System/Library/Fonts/SFNS.ttf"
FONT_AR = "/System/Library/Fonts/SFArabic.ttf"
FONT_CJK = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_FALLBACK = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"

SHOT_FEATURES = {
    "gallery": {
        "titles": {
            "en": "All your shots",
            "nl": "Al je shots",
            "pt": "Todas as capturas",
            "es": "Todas tus capturas",
            "fr": "Toutes vos captures",
            "it": "Tutti i tuoi scatti",
            "ar": "كل لقطاتك",
            "zh": "你的全部截图",
            "ru": "Все ваши снимки",
            "ja": "すべてのショット",
        },
        "descs": {
            "en": "Browse, search, and open captures in one clean gallery.",
            "nl": "Blader, zoek en open captures in één overzichtelijke galerij.",
            "pt": "Navegue, pesquise e abra capturas numa galeria limpa.",
            "es": "Explora, busca y abre capturas en una galería clara.",
            "fr": "Parcourez, recherchez et ouvrez vos captures dans une galerie claire.",
            "it": "Sfoglia, cerca e apri gli scatti in una galleria ordinata.",
            "ar": "تصفح وابحث وافتح اللقطات في معرض مرتب.",
            "zh": "在干净图库中浏览、搜索并打开截图。",
            "ru": "Просматривайте и открывайте снимки в удобной галерее.",
            "ja": "すっきりしたギャラリーでショットを閲覧・検索。",
        },
        "ui": {
            "en": {"nav": "Gallery", "hint": "New screenshots appear here automatically.", "rows": ["Login form", "Demo payslip", "Invoice PDF"]},
            "nl": {"nav": "Galerij", "hint": "Nieuwe schermafbeeldingen verschijnen hier automatisch.", "rows": ["Inlogformulier", "Demo loonstrook", "Factuur-PDF"]},
            "pt": {"nav": "Galeria", "hint": "Novas capturas aparecem aqui automaticamente.", "rows": ["Formulário de login", "Recibo demo", "PDF da fatura"]},
            "es": {"nav": "Galería", "hint": "Las capturas nuevas aparecen aquí automáticamente.", "rows": ["Formulario de acceso", "Nómina demo", "PDF de factura"]},
            "fr": {"nav": "Galerie", "hint": "Les nouvelles captures apparaissent ici automatiquement.", "rows": ["Formulaire de connexion", "Fiche de paie démo", "PDF de facture"]},
            "it": {"nav": "Galleria", "hint": "Le nuove schermate compaiono qui automaticamente.", "rows": ["Modulo di accesso", "Busta paga demo", "PDF fattura"]},
            "ar": {"nav": "المعرض", "hint": "تظهر لقطات الشاشة الجديدة هنا تلقائيًا.", "rows": ["نموذج تسجيل الدخول", "قسيمة راتب تجريبية", "فاتورة PDF"]},
            "zh": {"nav": "图库", "hint": "新截图会自动出现在这里。", "rows": ["登录表单", "演示工资单", "发票 PDF"]},
            "ru": {"nav": "Галерея", "hint": "Новые снимки появляются здесь автоматически.", "rows": ["Форма входа", "Демо расчётный лист", "PDF счёта"]},
            "ja": {"nav": "ギャラリー", "hint": "新しいスクリーンショットはここに自動で表示されます。", "rows": ["ログイン画面", "デモ給与明細", "請求書PDF"]},
        },
    },
    "editor": {
        "titles": {
            "en": "Quick edit",
            "nl": "Snel bewerken",
            "pt": "Edição rápida",
            "es": "Edición rápida",
            "fr": "Édition rapide",
            "it": "Modifica rapida",
            "ar": "تحرير سريع",
            "zh": "快速编辑",
            "ru": "Быстрое редактирование",
            "ja": "クイック編集",
        },
        "descs": {
            "en": "Draw, arrow, text, crop, blur, and black-box in one editor.",
            "nl": "Teken, pijl, tekst, bijsnijden, vervagen en zwartmaken in één editor.",
            "pt": "Desenhe, seta, texto, recorte, desfoque e caixa preta num só editor.",
            "es": "Dibuja, flecha, texto, recorte, desenfoque y caja negra en un editor.",
            "fr": "Dessin, flèche, texte, recadrage, flou et cadre noir dans un éditeur.",
            "it": "Disegno, freccia, testo, ritaglio, sfocatura e riquadro nero in un editor.",
            "ar": "ارسم وأضف أسهمًا ونصًا وقصًا وتمويهًا وصندوقًا أسود في محرر واحد.",
            "zh": "在一个编辑器中绘制、箭头、文字、裁剪、模糊与黑框。",
            "ru": "Рисование, стрелки, текст, обрезка, размытие и чёрный блок в одном редакторе.",
            "ja": "描画・矢印・テキスト・切り抜き・ぼかし・黒塗りを一つの編集画面で。",
        },
        "ui": {
            "en": {"nav": "Annotate", "tools": ["Select", "Arrow", "Text", "Blur", "Crop"], "note": "Call out what matters"},
            "nl": {"nav": "Annoteren", "tools": ["Selecteren", "Pijl", "Tekst", "Vervagen", "Bijsnijden"], "note": "Markeer wat telt"},
            "pt": {"nav": "Anotar", "tools": ["Selecionar", "Seta", "Texto", "Desfocar", "Recortar"], "note": "Destaque o essencial"},
            "es": {"nav": "Anotar", "tools": ["Seleccionar", "Flecha", "Texto", "Desenfocar", "Recortar"], "note": "Resalta lo importante"},
            "fr": {"nav": "Annoter", "tools": ["Sélection", "Flèche", "Texte", "Flou", "Recadrer"], "note": "Mettez en avant l’essentiel"},
            "it": {"nav": "Annota", "tools": ["Seleziona", "Freccia", "Testo", "Sfoca", "Ritaglia"], "note": "Evidenzia ciò che conta"},
            "ar": {"nav": "تعليق", "tools": ["تحديد", "سهم", "نص", "تمويه", "قص"], "note": "أبرز ما يهم"},
            "zh": {"nav": "批注", "tools": ["选择", "箭头", "文字", "模糊", "裁剪"], "note": "标出重点"},
            "ru": {"nav": "Разметка", "tools": ["Выбор", "Стрелка", "Текст", "Размытие", "Обрезка"], "note": "Выделите главное"},
            "ja": {"nav": "注釈", "tools": ["選択", "矢印", "テキスト", "ぼかし", "切り抜き"], "note": "大切な箇所を強調"},
        },
    },
    "redact": {
        "titles": {
            "en": "Hide secrets",
            "nl": "Verberg geheimen",
            "pt": "Oculte segredos",
            "es": "Oculta secretos",
            "fr": "Masquez les secrets",
            "it": "Nascondi i segreti",
            "ar": "أخفِ الأسرار",
            "zh": "隐藏机密",
            "ru": "Скрывайте секреты",
            "ja": "秘密を隠す",
        },
        "descs": {
            "en": "Auto-detect passwords, IBANs, and cards — blur in one tap.",
            "nl": "Detecteer wachtwoorden, IBANs en kaarten — vervagen met één tik.",
            "pt": "Deteta passwords, IBANs e cartões — desfoque com um toque.",
            "es": "Detecta contraseñas, IBAN y tarjetas — desenfoca con un toque.",
            "fr": "Détecte mots de passe, IBAN et cartes — floutez en un tap.",
            "it": "Rileva password, IBAN e carte — sfoca con un tocco.",
            "ar": "يكتشف كلمات المرور وأرقام الحساب والبطاقات — موّه بنقرة واحدة.",
            "zh": "自动检测密码、IBAN 与银行卡——一键模糊。",
            "ru": "Находит пароли, IBAN и карты — размытие в один тап.",
            "ja": "パスワード・IBAN・カードを自動検出。ワンタップでぼかし。",
        },
        "ui": {
            "en": {"nav": "Auto-blur", "status": "3 items ready to blur.", "tags": ["password", "iban", "card"]},
            "nl": {"nav": "Auto-vervagen", "status": "3 items klaar om te vervagen.", "tags": ["wachtwoord", "iban", "kaart"]},
            "pt": {"nav": "Desfoque automático", "status": "3 itens prontos para desfocar.", "tags": ["password", "iban", "cartão"]},
            "es": {"nav": "Desenfoque automático", "status": "3 elementos listos para desenfocar.", "tags": ["contraseña", "iban", "tarjeta"]},
            "fr": {"nav": "Flou auto", "status": "3 éléments prêts à flouter.", "tags": ["mot de passe", "iban", "carte"]},
            "it": {"nav": "Sfocatura automatica", "status": "3 elementi pronti da sfocare.", "tags": ["password", "iban", "carta"]},
            "ar": {"nav": "تمويه تلقائي", "status": "٣ عناصر جاهزة للتمويه.", "tags": ["كلمة مرور", "رقم حساب", "بطاقة"]},
            "zh": {"nav": "自动模糊", "status": "3 项可模糊。", "tags": ["密码", "iban", "银行卡"]},
            "ru": {"nav": "Авторазмытие", "status": "3 элемента готовы к размытию.", "tags": ["пароль", "iban", "карта"]},
            "ja": {"nav": "自動ぼかし", "status": "3件をぼかせます。", "tags": ["password", "iban", "card"]},
        },
    },
    "smart": {
        "titles": {
            "en": "Smart tools",
            "nl": "Slimme tools",
            "pt": "Ferramentas inteligentes",
            "es": "Herramientas inteligentes",
            "fr": "Outils intelligents",
            "it": "Strumenti smart",
            "ar": "أدوات ذكية",
            "zh": "智能工具",
            "ru": "Умные инструменты",
            "ja": "スマートツール",
        },
        "descs": {
            "en": "OCR copy text and pick hex colors straight from the shot.",
            "nl": "OCR tekst kopiëren en hex-kleuren kiezen direct uit de shot.",
            "pt": "Copie texto com OCR e escolha cores hex direto da captura.",
            "es": "Copia texto con OCR y elige colores hex desde la captura.",
            "fr": "Copiez le texte via OCR et prélevez les couleurs hex.",
            "it": "Copia testo con OCR e preleva colori esadecimali dallo scatto.",
            "ar": "انسخ النص بـ OCR والتقط ألوان hex مباشرة من اللقطة.",
            "zh": "OCR 复制文字，并从截图中拾取十六进制颜色。",
            "ru": "Копируйте текст через OCR и берите hex-цвета прямо со снимка.",
            "ja": "OCRでテキストコピー、ショットからHEXカラーを取得。",
        },
        "ui": {
            "en": {"nav": "Smart", "ocr": "Select text in the image like Preview.", "color": "#E85D22", "hint": "Click a pixel to copy its hex color."},
            "nl": {"nav": "Slim", "ocr": "Selecteer tekst zoals in Voorvertoning.", "color": "#E85D22", "hint": "Klik op een pixel om de hex-kleur te kopiëren."},
            "pt": {"nav": "Inteligente", "ocr": "Selecione texto como no Visualização.", "color": "#E85D22", "hint": "Clique em um pixel para copiar a cor hex."},
            "es": {"nav": "Inteligente", "ocr": "Selecciona texto como en Vista Previa.", "color": "#E85D22", "hint": "Haz clic en un píxel para copiar su color hex."},
            "fr": {"nav": "Intelligent", "ocr": "Sélectionnez du texte comme dans Aperçu.", "color": "#E85D22", "hint": "Cliquez sur un pixel pour copier sa couleur hex."},
            "it": {"nav": "Smart", "ocr": "Seleziona il testo come in Anteprima.", "color": "#E85D22", "hint": "Fai clic su un pixel per copiare il colore esadecimale."},
            "ar": {"nav": "ذكي", "ocr": "حدد النص كما في المعاينة.", "color": "#E85D22", "hint": "انقر على بكسل لنسخ لونه الست عشري."},
            "zh": {"nav": "智能", "ocr": "像“预览”一样选择文本。", "color": "#E85D22", "hint": "点击像素以复制其十六进制颜色。"},
            "ru": {"nav": "Умные", "ocr": "Выделяйте текст как в Просмотре.", "color": "#E85D22", "hint": "Нажмите на пиксель, чтобы скопировать hex-цвет."},
            "ja": {"nav": "スマート", "ocr": "プレビューのようにテキストを選択。", "color": "#E85D22", "hint": "ピクセルをクリックしてHEXカラーをコピー。"},
        },
    },
    "qr": {
        "titles": {
            "en": "Scan every QR",
            "nl": "Scan elke QR",
            "pt": "Leia cada QR",
            "es": "Escanea cada QR",
            "fr": "Scannez chaque QR",
            "it": "Scansiona ogni QR",
            "ar": "امسح كل QR",
            "zh": "扫描每个二维码",
            "ru": "Сканируйте любой QR",
            "ja": "すべてのQRを読取",
        },
        "descs": {
            "en": "List every QR in a shot — open links or copy payloads instantly.",
            "nl": "Lijst elke QR in een shot — open links of kopieer payloads direct.",
            "pt": "Liste cada QR na captura — abra links ou copie dados na hora.",
            "es": "Lista cada QR de la captura — abre enlaces o copia al instante.",
            "fr": "Liste chaque QR de la capture — ouvrez ou copiez immédiatement.",
            "it": "Elenca ogni QR nello scatto — apri link o copia all’istante.",
            "ar": "اعرض كل رموز QR في اللقطة — افتح الروابط أو انسخ المحتوى فورًا.",
            "zh": "列出截图中的每个二维码——立即打开链接或复制内容。",
            "ru": "Список всех QR на снимке — сразу откройте ссылку или скопируйте данные.",
            "ja": "ショット内の全QRを一覧。リンクを開くか内容を即コピー。",
        },
        "ui": {
            "en": {"nav": "QR scan", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
            "nl": {"nav": "QR-scan", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
            "pt": {"nav": "Leitura de QR", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
            "es": {"nav": "Escaneo QR", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
            "fr": {"nav": "Scan QR", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
            "it": {"nav": "Scansione QR", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
            "ar": {"nav": "مسح QR", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
            "zh": {"nav": "扫描二维码", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
            "ru": {"nav": "Скан QR", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
            "ja": {"nav": "QRスキャン", "items": ["https://buddy.app/invite", "wifi:BuddyOffice"]},
        },
    },
    "menubar": {
        "titles": {
            "en": "Menu bar ready",
            "nl": "Klaar in de menubalk",
            "pt": "Pronto na barra de menus",
            "es": "Listo en la barra de menús",
            "fr": "Prêt dans la barre de menus",
            "it": "Pronto nella barra dei menu",
            "ar": "جاهز في شريط القوائم",
            "zh": "菜单栏即用",
            "ru": "Всегда в меню",
            "ja": "メニューバーですぐに",
        },
        "descs": {
            "en": "Grab recent shots from the menu bar without leaving your flow.",
            "nl": "Pak recente shots vanuit de menubalk zonder je flow te verlaten.",
            "pt": "Aceda a capturas recentes na barra de menus sem sair do fluxo.",
            "es": "Accede a capturas recientes desde la barra sin salir de tu flujo.",
            "fr": "Accédez aux captures récentes depuis la barre sans quitter votre flux.",
            "it": "Prendi gli scatti recenti dalla barra senza interrompere il flusso.",
            "ar": "احصل على اللقطات الأخيرة من شريط القوائم دون مغادرة عملك.",
            "zh": "从菜单栏取用最近截图，不打断当前工作流。",
            "ru": "Берите недавние снимки из меню, не прерывая работу.",
            "ja": "作業を止めずにメニューバーから最近のショットへ。",
        },
        "ui": {
            "en": {"header": "Recent shots", "rows": ["Meeting notes", "•••• Sensitive", "Design mock"]},
            "nl": {"header": "Recente shots", "rows": ["Vergadernotities", "•••• Gevoelig", "Designmock"]},
            "pt": {"header": "Capturas recentes", "rows": ["Notas da reunião", "•••• Sensível", "Mock de design"]},
            "es": {"header": "Capturas recientes", "rows": ["Notas de reunión", "•••• Sensible", "Mock de diseño"]},
            "fr": {"header": "Captures récentes", "rows": ["Notes de réunion", "•••• Sensible", "Maquette"]},
            "it": {"header": "Scatti recenti", "rows": ["Note riunione", "•••• Sensibile", "Mock design"]},
            "ar": {"header": "اللقطات الأخيرة", "rows": ["ملاحظات الاجتماع", "•••• حساس", "نموذج تصميم"]},
            "zh": {"header": "最近截图", "rows": ["会议笔记", "•••• 敏感", "设计稿"]},
            "ru": {"header": "Недавние снимки", "rows": ["Заметки встречи", "•••• Конфиденциально", "Макет"]},
            "ja": {"header": "最近のショット", "rows": ["会議メモ", "•••• 機密", "デザイン案"]},
        },
    },
}

CLIP_FEATURES = {
    "history": {
        "titles": {
            "en": "Never lose a copy",
            "nl": "Nooit meer kwijt",
            "pt": "Nunca perca uma cópia",
            "es": "Nunca pierdas una copia",
            "fr": "Ne perdez plus une copie",
            "it": "Non perdere mai una copia",
            "ar": "لا تفقد أي نسخ",
            "zh": "再也不丢复制内容",
            "ru": "Ничего не теряется",
            "ja": "コピーを逃さない",
        },
        "descs": {
            "en": "Search every text, image, and file you copied on your Mac.",
            "nl": "Zoek elke tekst, afbeelding en elk bestand dat je kopieerde.",
            "pt": "Pesquise todo texto, imagem e ficheiro que copiou no Mac.",
            "es": "Busca cada texto, imagen y archivo que copiaste en tu Mac.",
            "fr": "Recherchez chaque texte, image et fichier copié sur votre Mac.",
            "it": "Cerca ogni testo, immagine e file copiato sul Mac.",
            "ar": "ابحث في كل نص وصورة وملف نسخته على جهاز Mac.",
            "zh": "搜索你在 Mac 上复制过的每个文本、图像和文件。",
            "ru": "Ищите любой текст, изображение и файл, скопированные на Mac.",
            "ja": "Macでコピーしたテキスト・画像・ファイルをすべて検索。",
        },
        "ui": {
            "en": {"nav": "History", "search": "Search", "rows": [("https://docs.buddy.app", ["url"]), ("Meeting agenda draft", ["text"]), ("#10B981", ["color"])]},
            "nl": {"nav": "Geschiedenis", "search": "Zoeken", "rows": [("https://docs.buddy.app", ["url"]), ("Agenda vergadering", ["text"]), ("#10B981", ["color"])]},
            "pt": {"nav": "Histórico", "search": "Pesquisar", "rows": [("https://docs.buddy.app", ["url"]), ("Rascunho da agenda", ["text"]), ("#10B981", ["color"])]},
            "es": {"nav": "Historial", "search": "Buscar", "rows": [("https://docs.buddy.app", ["url"]), ("Borrador de agenda", ["text"]), ("#10B981", ["color"])]},
            "fr": {"nav": "Historique", "search": "Rechercher", "rows": [("https://docs.buddy.app", ["url"]), ("Brouillon d’ordre du jour", ["text"]), ("#10B981", ["color"])]},
            "it": {"nav": "Cronologia", "search": "Cerca", "rows": [("https://docs.buddy.app", ["url"]), ("Bozza agenda", ["text"]), ("#10B981", ["color"])]},
            "ar": {"nav": "السجل", "search": "بحث", "rows": [("https://docs.buddy.app", ["url"]), ("مسودة جدول الأعمال", ["text"]), ("#10B981", ["color"])]},
            "zh": {"nav": "历史记录", "search": "搜索", "rows": [("https://docs.buddy.app", ["url"]), ("会议议程草稿", ["text"]), ("#10B981", ["color"])]},
            "ru": {"nav": "История", "search": "Поиск", "rows": [("https://docs.buddy.app", ["url"]), ("Черновик повестки", ["text"]), ("#10B981", ["color"])]},
            "ja": {"nav": "履歴", "search": "検索", "rows": [("https://docs.buddy.app", ["url"]), ("議事アジェンダ下書き", ["text"]), ("#10B981", ["color"])]},
        },
    },
    "tags": {
        "titles": {
            "en": "Smart tags",
            "nl": "Slimme tags",
            "pt": "Tags inteligentes",
            "es": "Etiquetas inteligentes",
            "fr": "Tags intelligents",
            "it": "Tag smart",
            "ar": "وسوم ذكية",
            "zh": "智能标签",
            "ru": "Умные теги",
            "ja": "スマートタグ",
        },
        "descs": {
            "en": "Passwords stay blurred until you unlock with Touch ID or password.",
            "nl": "Wachtwoorden blijven wazig tot je ontgrendelt met Touch ID of wachtwoord.",
            "pt": "Passwords ficam desfocadas até desbloquear com Touch ID ou password.",
            "es": "Las contraseñas se desenfocan hasta desbloquear con Touch ID o contraseña.",
            "fr": "Les mots de passe restent floutés jusqu’au déverrouillage Touch ID ou mot de passe.",
            "it": "Le password restano sfocate finché non sblocchi con Touch ID o password.",
            "ar": "تبقى كلمات المرور مموهة حتى تفتحها بـ Touch ID أو كلمة المرور.",
            "zh": "密码保持模糊，直到用 Touch ID 或密码解锁。",
            "ru": "Пароли размыты, пока вы не разблокируете Touch ID или паролем.",
            "ja": "パスワードはTouch IDまたはパスワードで解除するまでぼかされます。",
        },
        "ui": {
            "en": {"nav": "History", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
            "nl": {"nav": "Geschiedenis", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
            "pt": {"nav": "Histórico", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
            "es": {"nav": "Historial", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
            "fr": {"nav": "Historique", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
            "it": {"nav": "Cronologia", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
            "ar": {"nav": "السجل", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
            "zh": {"nav": "历史记录", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
            "ru": {"nav": "История", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
            "ja": {"nav": "履歴", "rows": [("••••••••••••", ["password"], True), ("NL91 ABNA 0417 1643 00", ["iban"], True), ("sk_live_51Hq…", ["apiKey"], True)]},
        },
    },
    "favorites": {
        "titles": {
            "en": "One-click favorites",
            "nl": "Favorieten in één klik",
            "pt": "Favoritos com um clique",
            "es": "Favoritos en un clic",
            "fr": "Favoris en un clic",
            "it": "Preferiti in un clic",
            "ar": "مفضلات بنقرة واحدة",
            "zh": "一键收藏",
            "ru": "Избранное в один клик",
            "ja": "ワンクリックお気に入り",
        },
        "descs": {
            "en": "Pin shortcuts to the menu bar for instant paste.",
            "nl": "Pin snelkoppelingen in de menubalk voor direct plakken.",
            "pt": "Fixe atalhos na barra de menus para colar na hora.",
            "es": "Fija atajos en la barra de menús para pegar al instante.",
            "fr": "Épinglez des raccourcis dans la barre pour coller instantanément.",
            "it": "Fissa scorciatoie nella barra dei menu per incollare subito.",
            "ar": "ثبّت الاختصارات في شريط القوائم للصق الفوري.",
            "zh": "将快捷项固定到菜单栏，即时粘贴。",
            "ru": "Закрепите ярлыки в меню для мгновенной вставки.",
            "ja": "メニューバーにショートカットを固定して即ペースト。",
        },
        "ui": {
            "en": {"header": "Favorites", "rows": [("Work email", "you@company.com"), ("Support link", "https://help.buddy.app"), ("Brand green", "#10B981")]},
            "nl": {"header": "Favorieten", "rows": [("Werkmail", "you@company.com"), ("Supportlink", "https://help.buddy.app"), ("Merkgroen", "#10B981")]},
            "pt": {"header": "Favoritos", "rows": [("E-mail do trabalho", "you@company.com"), ("Link de suporte", "https://help.buddy.app"), ("Verde da marca", "#10B981")]},
            "es": {"header": "Favoritos", "rows": [("Correo laboral", "you@company.com"), ("Enlace de soporte", "https://help.buddy.app"), ("Verde de marca", "#10B981")]},
            "fr": {"header": "Favoris", "rows": [("E-mail pro", "you@company.com"), ("Lien support", "https://help.buddy.app"), ("Vert marque", "#10B981")]},
            "it": {"header": "Preferiti", "rows": [("Email lavoro", "you@company.com"), ("Link supporto", "https://help.buddy.app"), ("Verde brand", "#10B981")]},
            "ar": {"header": "المفضلة", "rows": [("بريد العمل", "you@company.com"), ("رابط الدعم", "https://help.buddy.app"), ("أخضر العلامة", "#10B981")]},
            "zh": {"header": "收藏", "rows": [("工作邮箱", "you@company.com"), ("支持链接", "https://help.buddy.app"), ("品牌绿", "#10B981")]},
            "ru": {"header": "Избранное", "rows": [("Рабочая почта", "you@company.com"), ("Ссылка поддержки", "https://help.buddy.app"), ("Фирменный зелёный", "#10B981")]},
            "ja": {"header": "お気に入り", "rows": [("仕事メール", "you@company.com"), ("サポートリンク", "https://help.buddy.app"), ("ブランド緑", "#10B981")]},
        },
    },
    "qr": {
        "titles": {
            "en": "Make a QR",
            "nl": "Maak een QR",
            "pt": "Crie um QR",
            "es": "Crea un QR",
            "fr": "Créez un QR",
            "it": "Crea un QR",
            "ar": "أنشئ رمز QR",
            "zh": "生成二维码",
            "ru": "Создайте QR",
            "ja": "QRを作成",
        },
        "descs": {
            "en": "Turn any history item into a scannable QR code image.",
            "nl": "Maak van elk geschiedenisitem een scanbare QR-code.",
            "pt": "Transforme qualquer item do histórico num QR code escaneável.",
            "es": "Convierte cualquier elemento del historial en un código QR.",
            "fr": "Transformez tout élément d’historique en image QR scannable.",
            "it": "Trasforma qualsiasi voce della cronologia in un QR scansionabile.",
            "ar": "حوّل أي عنصر من السجل إلى صورة رمز QR قابلة للمسح.",
            "zh": "将任意历史项变成可扫描的二维码图像。",
            "ru": "Превращайте любой элемент истории в сканируемый QR-код.",
            "ja": "履歴の項目をスキャン可能なQRコード画像に。",
        },
        "ui": {
            "en": {"nav": "QR Code", "payload": "https://buddy.app/share/42", "action": "Copy Image"},
            "nl": {"nav": "QR-code", "payload": "https://buddy.app/share/42", "action": "Afbeelding kopiëren"},
            "pt": {"nav": "Código QR", "payload": "https://buddy.app/share/42", "action": "Copiar imagem"},
            "es": {"nav": "Código QR", "payload": "https://buddy.app/share/42", "action": "Copiar imagen"},
            "fr": {"nav": "Code QR", "payload": "https://buddy.app/share/42", "action": "Copier l’image"},
            "it": {"nav": "Codice QR", "payload": "https://buddy.app/share/42", "action": "Copia immagine"},
            "ar": {"nav": "رمز QR", "payload": "https://buddy.app/share/42", "action": "نسخ الصورة"},
            "zh": {"nav": "二维码", "payload": "https://buddy.app/share/42", "action": "复制图像"},
            "ru": {"nav": "QR-код", "payload": "https://buddy.app/share/42", "action": "Копировать изображение"},
            "ja": {"nav": "QRコード", "payload": "https://buddy.app/share/42", "action": "画像をコピー"},
        },
    },
    "detail": {
        "titles": {
            "en": "Rich detail",
            "nl": "Rijke details",
            "pt": "Detalhe completo",
            "es": "Detalle completo",
            "fr": "Détail riche",
            "it": "Dettaglio completo",
            "ar": "تفاصيل غنية",
            "zh": "完整详情",
            "ru": "Подробности",
            "ja": "詳細ビュー",
        },
        "descs": {
            "en": "Preview text, images, and pasteboard flavors before you paste.",
            "nl": "Bekijk tekst, afbeeldingen en klembordtypes vóór je plakt.",
            "pt": "Pré-visualize texto, imagens e formatos antes de colar.",
            "es": "Previsualiza texto, imágenes y formatos antes de pegar.",
            "fr": "Prévisualisez texte, images et formats avant de coller.",
            "it": "Anteprima di testo, immagini e formati prima di incollare.",
            "ar": "عاين النص والصور وأنواع الحافظة قبل اللصق.",
            "zh": "粘贴前预览文本、图像与剪贴板格式。",
            "ru": "Просматривайте текст, изображения и форматы буфера перед вставкой.",
            "ja": "ペースト前にテキスト・画像・形式をプレビュー。",
        },
        "ui": {
            "en": {"nav": "History", "title": "Release notes draft", "meta": "2 pasteboard flavors stored", "body": "• Faster OCR\n• Menu bar pause\n• Privacy unlock session"},
            "nl": {"nav": "Geschiedenis", "title": "Concept releasenotes", "meta": "2 klembordtypes opgeslagen", "body": "• Snellere OCR\n• Pauze in menubalk\n• Privacy-ontgrendeling"},
            "pt": {"nav": "Histórico", "title": "Rascunho de notas", "meta": "2 formatos armazenados", "body": "• OCR mais rápido\n• Pausa na barra\n• Sessão de desbloqueio"},
            "es": {"nav": "Historial", "title": "Borrador de notas", "meta": "2 formatos guardados", "body": "• OCR más rápido\n• Pausa en la barra\n• Sesión de desbloqueo"},
            "fr": {"nav": "Historique", "title": "Brouillon de notes", "meta": "2 formats enregistrés", "body": "• OCR plus rapide\n• Pause barre de menus\n• Session de déverrouillage"},
            "it": {"nav": "Cronologia", "title": "Bozza note di rilascio", "meta": "2 formati salvati", "body": "• OCR più veloce\n• Pausa barra menu\n• Sessione di sblocco"},
            "ar": {"nav": "السجل", "title": "مسودة ملاحظات الإصدار", "meta": "تم حفظ نوعين من الحافظة", "body": "• OCR أسرع\n• إيقاف شريط القوائم\n• جلسة فتح الخصوصية"},
            "zh": {"nav": "历史记录", "title": "发行说明草稿", "meta": "已存储 2 种剪贴板格式", "body": "• 更快的 OCR\n• 菜单栏暂停\n• 隐私解锁会话"},
            "ru": {"nav": "История", "title": "Черновик релиз-нот", "meta": "Сохранено форматов: 2", "body": "• Быстрее OCR\n• Пауза в меню\n• Сессия разблокировки"},
            "ja": {"nav": "履歴", "title": "リリースノート下書き", "meta": "2件の形式を保存", "body": "• OCR高速化\n• メニューバー一時停止\n• プライバシー解除セッション"},
        },
    },
    "menubar": {
        "titles": {
            "en": "Always nearby",
            "nl": "Altijd dichtbij",
            "pt": "Sempre por perto",
            "es": "Siempre a mano",
            "fr": "Toujours à portée",
            "it": "Sempre a portata",
            "ar": "دائمًا في المتناول",
            "zh": "随时可用",
            "ru": "Всегда под рукой",
            "ja": "いつもそばに",
        },
        "descs": {
            "en": "Favorites and recent clips live in the menu bar.",
            "nl": "Favorieten en recente clips in de menubalk.",
            "pt": "Favoritos e clips recentes na barra de menus.",
            "es": "Favoritos y clips recientes en la barra de menús.",
            "fr": "Favoris et clips récents dans la barre de menus.",
            "it": "Preferiti e clip recenti nella barra dei menu.",
            "ar": "المفضلات والمقاطع الأخيرة في شريط القوائم.",
            "zh": "收藏与最近剪贴内容就在菜单栏。",
            "ru": "Избранное и недавние клипы — в меню.",
            "ja": "お気に入りと最近のクリップはメニューバーに。",
        },
        "ui": {
            "en": {"fav": "Favorites", "recent": "Recent", "fav_rows": ["Support link", "Brand green"], "recent_rows": ["•••• password", "Meeting notes"]},
            "nl": {"fav": "Favorieten", "recent": "Recent", "fav_rows": ["Supportlink", "Merkgroen"], "recent_rows": ["•••• wachtwoord", "Vergadernotities"]},
            "pt": {"fav": "Favoritos", "recent": "Recentes", "fav_rows": ["Link de suporte", "Verde da marca"], "recent_rows": ["•••• password", "Notas da reunião"]},
            "es": {"fav": "Favoritos", "recent": "Recientes", "fav_rows": ["Enlace de soporte", "Verde de marca"], "recent_rows": ["•••• contraseña", "Notas de reunión"]},
            "fr": {"fav": "Favoris", "recent": "Récent", "fav_rows": ["Lien support", "Vert marque"], "recent_rows": ["•••• mot de passe", "Notes de réunion"]},
            "it": {"fav": "Preferiti", "recent": "Recenti", "fav_rows": ["Link supporto", "Verde brand"], "recent_rows": ["•••• password", "Note riunione"]},
            "ar": {"fav": "المفضلة", "recent": "الأخيرة", "fav_rows": ["رابط الدعم", "أخضر العلامة"], "recent_rows": ["•••• كلمة مرور", "ملاحظات الاجتماع"]},
            "zh": {"fav": "收藏", "recent": "最近", "fav_rows": ["支持链接", "品牌绿"], "recent_rows": ["•••• 密码", "会议笔记"]},
            "ru": {"fav": "Избранное", "recent": "Недавние", "fav_rows": ["Ссылка поддержки", "Фирменный зелёный"], "recent_rows": ["•••• пароль", "Заметки встречи"]},
            "ja": {"fav": "お気に入り", "recent": "最近", "fav_rows": ["サポートリンク", "ブランド緑"], "recent_rows": ["•••• パスワード", "会議メモ"]},
        },
    },
}


def shape(text: str, lang: str) -> str:
    """Reshape Arabic; protect Latin/digit tokens so mixed strings stay readable."""
    if lang != "ar" or not arabic_reshaper or not get_display:
        return text
    import re

    holders: list[str] = []

    def protect(match: re.Match[str]) -> str:
        holders.append(match.group(0))
        return f"[[T{len(holders) - 1}]]"

    protected = re.sub(r"[A-Za-z0-9#:/._%+-]+", protect, text)
    shaped = get_display(arabic_reshaper.reshape(protected))
    for i, token in enumerate(holders):
        for needle in (f"[[T{i}]]", get_display(arabic_reshaper.reshape(f"[[T{i}]]"))):
            shaped = shaped.replace(needle, token)
    return shaped


def font(size: int, lang: str, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = []
    if lang == "ar":
        candidates.append(FONT_AR)
    if lang in {"zh", "ja"}:
        candidates.append(FONT_CJK)
    candidates.extend([FONT_LATIN, FONT_FALLBACK])
    for path in candidates:
        try:
            if path.endswith(".ttc"):
                return ImageFont.truetype(path, size=size, index=0)
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def gradient(size: tuple[int, int], colors: dict) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        if t < 0.5:
            u = t / 0.5
            a, b = colors["top"], colors["mid"]
        else:
            u = (t - 0.5) / 0.5
            a, b = colors["mid"], colors["bot"]
        rgb = tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3))
        for x in range(w):
            # subtle vignette
            cx, cy = (x / w - 0.5), (y / h - 0.5)
            v = 1 - 0.12 * (cx * cx + cy * cy) * 4
            px[x, y] = tuple(max(0, min(255, int(c * v))) for c in rgb)
    return img


def round_rect(draw: ImageDraw.ImageDraw, box, radius: int, fill, outline=None, width: int = 1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_window_chrome(draw: ImageDraw.ImageDraw, box, title: str, lang: str):
    x0, y0, x1, y1 = box
    round_rect(draw, box, 14, fill=(255, 255, 255), outline=(0, 0, 0, 30), width=1)
    # title bar
    round_rect(draw, (x0, y0, x1, y0 + 36), 14, fill=(246, 246, 248))
    draw.rectangle((x0, y0 + 22, x1, y0 + 36), fill=(246, 246, 248))
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        draw.ellipse((x0 + 14 + i * 18, y0 + 12, x0 + 24 + i * 18, y0 + 22), fill=c)
    f = font(13, lang)
    tw = draw.textlength(shape(title, lang), font=f)
    draw.text(((x0 + x1 - tw) / 2, y0 + 10), shape(title, lang), fill=(60, 60, 67), font=f)


def mock_shot_gallery(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), colors["ui_bg"])
    d = ImageDraw.Draw(img)
    draw_window_chrome(d, (20, 20, RAW_W - 20, RAW_H - 20), ui["nav"], lang)
    # sidebar
    d.rectangle((20, 56, 280, RAW_H - 20), fill=colors["sidebar"])
    f = font(14, lang)
    for i, row in enumerate(ui["rows"]):
        y = 80 + i * 70
        round_rect(d, (36, y, 264, y + 56), 8, fill=(255, 255, 255))
        d.rounded_rectangle((48, y + 10, 100, y + 46), 4, fill=colors["chip"])
        d.text((112, y + 18), shape(row, lang), fill=(40, 40, 40), font=f)
    # canvas preview
    round_rect(d, (300, 80, RAW_W - 40, RAW_H - 50), 12, fill=(255, 255, 255), outline=(220, 220, 220))
    # fake screenshot content
    d.rounded_rectangle((340, 120, RAW_W - 80, 280), 10, fill=(255, 236, 220))
    d.rounded_rectangle((360, 150, 520, 180), 6, fill=colors["accent"])
    d.rounded_rectangle((360, 200, RAW_W - 120, 220), 4, fill=(230, 210, 190))
    d.rounded_rectangle((360, 235, RAW_W - 180, 255), 4, fill=(230, 210, 190))
    hint = font(13, lang)
    d.text((340, RAW_H - 90), shape(ui["hint"], lang), fill=(110, 110, 115), font=hint)
    return img


def mock_shot_editor(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), colors["ui_bg"])
    d = ImageDraw.Draw(img)
    draw_window_chrome(d, (20, 20, RAW_W - 20, RAW_H - 20), ui["nav"], lang)
    # toolbar
    x = 40
    tf = font(12, lang)
    for tool in ui["tools"]:
        w = int(d.textlength(shape(tool, lang), font=tf)) + 24
        round_rect(d, (x, 70, x + w, 98), 8, fill=colors["chip"] if tool == ui["tools"][1] else (255, 255, 255), outline=(210, 210, 210))
        d.text((x + 12, 76), shape(tool, lang), fill=(40, 40, 40), font=tf)
        x += w + 8
    # canvas
    round_rect(d, (40, 120, RAW_W - 40, RAW_H - 40), 12, fill=(255, 255, 255), outline=(220, 220, 220))
    d.rounded_rectangle((80, 160, RAW_W - 80, 360), 10, fill=(255, 240, 228))
    # arrow + note
    d.line((220, 300, 420, 210), fill=colors["accent"], width=4)
    d.polygon([(420, 210), (400, 208), (408, 226)], fill=colors["accent"])
    nf = font(16, lang, bold=True)
    d.text((440, 190), shape(ui["note"], lang), fill=colors["accent"], font=nf)
    # black box redaction sample
    d.rectangle((140, 240, 340, 270), fill=(20, 20, 20))
    return img


def mock_shot_redact(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), colors["ui_bg"])
    d = ImageDraw.Draw(img)
    draw_window_chrome(d, (20, 20, RAW_W - 20, RAW_H - 20), ui["nav"], lang)
    round_rect(d, (40, 70, RAW_W - 40, RAW_H - 40), 12, fill=(255, 255, 255))
    d.rounded_rectangle((70, 110, RAW_W - 70, 320), 10, fill=(250, 246, 240))
    # blurred strips
    for i, tag in enumerate(ui["tags"]):
        y = 140 + i * 50
        strip = Image.new("RGB", (420, 28), (180, 170, 160))
        strip = strip.filter(ImageFilter.GaussianBlur(4))
        img.paste(strip, (100, y))
        d = ImageDraw.Draw(img)
        round_rect(d, (540, y, 540 + int(d.textlength(shape(tag, lang), font=font(12, lang))) + 20, y + 28), 8, fill=colors["chip"])
        d.text((550, y + 6), shape(tag, lang), fill=(80, 50, 20), font=font(12, lang))
    d = ImageDraw.Draw(img)
    status = shape(ui["status"], lang)
    sf = font(14, lang)
    sw = int(d.textlength(status, font=sf)) + 40
    round_rect(d, (70, 360, 70 + sw, 410), 10, fill=colors["accent"])
    d.text((90, 375), status, fill=(255, 255, 255), font=sf)
    return img


def mock_shot_smart(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), colors["ui_bg"])
    d = ImageDraw.Draw(img)
    draw_window_chrome(d, (20, 20, RAW_W - 20, RAW_H - 20), ui["nav"], lang)
    round_rect(d, (40, 70, 620, RAW_H - 40), 12, fill=(255, 255, 255))
    d.rounded_rectangle((70, 110, 590, 280), 8, fill=(255, 236, 220))
    # selection highlight
    d.rectangle((120, 160, 420, 190), fill=(255, 214, 102, 120) if False else (255, 230, 150))
    d.text((130, 166), shape("Account settings", lang) if lang == "en" else shape(ui["ocr"][:18], lang), fill=(40, 40, 40), font=font(14, lang))
    panel_x = 650
    round_rect(d, (panel_x, 70, RAW_W - 40, RAW_H - 40), 12, fill=colors["sidebar"])
    d.text((panel_x + 24, 100), "OCR", fill=(40, 40, 40), font=font(18, lang))
    d.text((panel_x + 24, 140), shape(ui["ocr"], lang), fill=(90, 90, 95), font=font(13, lang))
    d.ellipse((panel_x + 24, 260, panel_x + 64, 300), fill=tuple(int(ui["color"].lstrip("#")[i:i+2], 16) for i in (0, 2, 4)))
    d.text((panel_x + 80, 270), ui["color"], fill=(40, 40, 40), font=font(16, lang))
    d.text((panel_x + 24, 330), shape(ui["hint"], lang), fill=(90, 90, 95), font=font(12, lang))
    return img


def mock_shot_qr(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), colors["ui_bg"])
    d = ImageDraw.Draw(img)
    draw_window_chrome(d, (20, 20, RAW_W - 20, RAW_H - 20), ui["nav"], lang)
    # fake QR blocks
    qr = Image.new("RGB", (220, 220), (255, 255, 255))
    qd = ImageDraw.Draw(qr)
    for r in range(11):
        for c in range(11):
            if (r * c + r + c) % 3 == 0 or (r < 3 and c < 3) or (r < 3 and c > 7) or (r > 7 and c < 3):
                qd.rectangle((10 + c * 18, 10 + r * 18, 26 + c * 18, 26 + r * 18), fill=(20, 20, 20))
    img.paste(qr, (80, 100))
    d = ImageDraw.Draw(img)
    y = 120
    for item in ui["items"]:
        round_rect(d, (340, y, RAW_W - 60, y + 70), 10, fill=(255, 255, 255), outline=(220, 220, 220))
        d.text((360, y + 24), shape(item, lang), fill=(40, 40, 40), font=font(15, lang))
        y += 90
    return img


def mock_shot_menubar(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), (40, 42, 48))
    # soft desktop
    for y in range(RAW_H):
        t = y / RAW_H
        c = tuple(int(colors["top"][i] * (1 - t) * 0.35 + 30) for i in range(3))
        ImageDraw.Draw(img).line((0, y, RAW_W, y), fill=c)
    d = ImageDraw.Draw(img)
    pop = (RAW_W // 2 - 180, 80, RAW_W // 2 + 180, RAW_H - 80)
    round_rect(d, pop, 14, fill=(250, 250, 252))
    d.text((pop[0] + 24, pop[1] + 20), shape(ui["header"], lang), fill=(30, 30, 30), font=font(16, lang))
    for i, row in enumerate(ui["rows"]):
        y = pop[1] + 70 + i * 70
        round_rect(d, (pop[0] + 16, y, pop[2] - 16, y + 56), 8, fill=colors["sidebar"])
        d.rounded_rectangle((pop[0] + 28, y + 12, pop[0] + 68, y + 44), 4, fill=colors["chip"])
        d.text((pop[0] + 84, y + 18), shape(row, lang), fill=(40, 40, 40), font=font(14, lang))
    return img


def mock_clip_history(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), colors["ui_bg"])
    d = ImageDraw.Draw(img)
    draw_window_chrome(d, (20, 20, RAW_W - 20, RAW_H - 20), ui["nav"], lang)
    d.rectangle((20, 56, 320, RAW_H - 20), fill=colors["sidebar"])
    # search
    round_rect(d, (36, 72, 304, 104), 8, fill=(255, 255, 255), outline=(210, 210, 210))
    d.text((48, 80), shape(ui["search"], lang), fill=(140, 140, 145), font=font(13, lang))
    for i, (preview, tags) in enumerate(ui["rows"]):
        y = 120 + i * 80
        round_rect(d, (36, y, 304, y + 68), 8, fill=(255, 255, 255))
        d.text((48, y + 12), shape(preview, lang), fill=(30, 30, 30), font=font(13, lang))
        tx = 48
        for tag in tags:
            tw = int(d.textlength(tag, font=font(11, lang))) + 14
            round_rect(d, (tx, y + 38, tx + tw, y + 56), 6, fill=colors["chip"])
            d.text((tx + 7, y + 40), tag, fill=(20, 80, 50), font=font(11, lang))
            tx += tw + 6
    # detail
    round_rect(d, (350, 80, RAW_W - 40, RAW_H - 40), 12, fill=(255, 255, 255))
    d.text((380, 120), shape(ui["rows"][0][0], lang), fill=(20, 20, 20), font=font(20, lang))
    d.text((380, 170), "url · text", fill=(120, 120, 125), font=font(13, lang))
    return img


def mock_clip_tags(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), colors["ui_bg"])
    d = ImageDraw.Draw(img)
    draw_window_chrome(d, (20, 20, RAW_W - 20, RAW_H - 20), ui["nav"], lang)
    for i, (preview, tags, hidden) in enumerate(ui["rows"]):
        y = 80 + i * 100
        round_rect(d, (50, y, RAW_W - 50, y + 84), 12, fill=(255, 255, 255), outline=(220, 220, 220))
        if hidden:
            blur = Image.new("RGB", (420, 28), (170, 180, 175))
            blur = blur.filter(ImageFilter.GaussianBlur(5))
            img.paste(blur, (70, y + 18))
            d = ImageDraw.Draw(img)
            d.text((70, y + 18), "••••••••••••", fill=(90, 90, 95), font=font(16, lang))
        else:
            d.text((70, y + 18), shape(preview, lang), fill=(30, 30, 30), font=font(16, lang))
        tx = 70
        for tag in tags:
            tw = int(d.textlength(tag, font=font(11, lang))) + 16
            round_rect(d, (tx, y + 50, tx + tw, y + 70), 7, fill=colors["chip"])
            d.text((tx + 8, y + 53), tag, fill=(20, 80, 50), font=font(11, lang))
            tx += tw + 8
        # lock icon circle
        d.ellipse((RAW_W - 110, y + 26, RAW_W - 78, y + 58), fill=colors["accent"])
    return img


def mock_clip_favorites(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), (35, 40, 38))
    for y in range(RAW_H):
        t = y / RAW_H
        c = tuple(int(colors["mid"][i] * (1 - t) * 0.4 + 28) for i in range(3))
        ImageDraw.Draw(img).line((0, y, RAW_W, y), fill=c)
    d = ImageDraw.Draw(img)
    pop = (RAW_W // 2 - 200, 70, RAW_W // 2 + 200, RAW_H - 70)
    round_rect(d, pop, 14, fill=(250, 252, 250))
    d.text((pop[0] + 24, pop[1] + 22), shape(ui["header"], lang), fill=(20, 20, 20), font=font(17, lang))
    for i, (name, content) in enumerate(ui["rows"]):
        y = pop[1] + 70 + i * 80
        round_rect(d, (pop[0] + 16, y, pop[2] - 16, y + 66), 10, fill=colors["sidebar"])
        d.text((pop[0] + 32, y + 12), shape(name, lang), fill=(20, 20, 20), font=font(14, lang))
        d.text((pop[0] + 32, y + 36), content, fill=(100, 110, 105), font=font(12, lang))
    return img


def mock_clip_qr(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), colors["ui_bg"])
    d = ImageDraw.Draw(img)
    draw_window_chrome(d, (20, 20, RAW_W - 20, RAW_H - 20), ui["nav"], lang)
    qr = Image.new("RGB", (260, 260), (255, 255, 255))
    qd = ImageDraw.Draw(qr)
    for r in range(13):
        for c in range(13):
            if (r + c * 2) % 3 != 1 or r in (0, 1, 2, 10, 11, 12) or c in (0, 1, 2, 10, 11, 12):
                if (r < 3 and c < 3) or (r < 3 and c > 9) or (r > 9 and c < 3) or ((r * 3 + c) % 4 == 0):
                    qd.rectangle((8 + c * 18, 8 + r * 18, 24 + c * 18, 24 + r * 18), fill=(15, 15, 15))
    img.paste(qr, ((RAW_W - 260) // 2, 110))
    d = ImageDraw.Draw(img)
    payload = shape(ui["payload"], lang)
    tw = d.textlength(payload, font=font(14, lang))
    d.text(((RAW_W - tw) / 2, 400), payload, fill=(50, 50, 55), font=font(14, lang))
    aw = int(d.textlength(shape(ui["action"], lang), font=font(14, lang))) + 36
    ax = (RAW_W - aw) // 2
    round_rect(d, (ax, 450, ax + aw, 490), 10, fill=colors["accent"])
    d.text((ax + 18, 460), shape(ui["action"], lang), fill=(255, 255, 255), font=font(14, lang))
    return img


def mock_clip_detail(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), colors["ui_bg"])
    d = ImageDraw.Draw(img)
    draw_window_chrome(d, (20, 20, RAW_W - 20, RAW_H - 20), ui["nav"], lang)
    d.rectangle((20, 56, 280, RAW_H - 20), fill=colors["sidebar"])
    for i in range(3):
        y = 80 + i * 70
        round_rect(d, (36, y, 264, y + 56), 8, fill=(255, 255, 255) if i == 0 else (245, 250, 247))
    round_rect(d, (300, 70, RAW_W - 40, RAW_H - 40), 12, fill=(255, 255, 255))
    d.text((330, 100), shape(ui["title"], lang), fill=(20, 20, 20), font=font(22, lang))
    d.text((330, 145), shape(ui["meta"], lang), fill=(110, 120, 115), font=font(13, lang))
    y = 200
    for line in ui["body"].split("\n"):
        d.text((330, y), shape(line, lang), fill=(40, 40, 40), font=font(15, lang))
        y += 34
    return img


def mock_clip_menubar(lang: str, colors: dict, ui: dict) -> Image.Image:
    img = Image.new("RGB", (RAW_W, RAW_H), (30, 36, 34))
    for y in range(RAW_H):
        t = y / RAW_H
        c = tuple(int(colors["bot"][i] * (1 - t) * 0.35 + 25) for i in range(3))
        ImageDraw.Draw(img).line((0, y, RAW_W, y), fill=c)
    d = ImageDraw.Draw(img)
    pop = (RAW_W // 2 - 190, 60, RAW_W // 2 + 190, RAW_H - 60)
    round_rect(d, pop, 14, fill=(250, 252, 250))
    d.text((pop[0] + 22, pop[1] + 18), shape(ui["fav"], lang), fill=(20, 20, 20), font=font(15, lang))
    y = pop[1] + 50
    for row in ui["fav_rows"]:
        round_rect(d, (pop[0] + 16, y, pop[2] - 16, y + 44), 8, fill=colors["sidebar"])
        d.text((pop[0] + 28, y + 12), shape(row, lang), fill=(30, 30, 30), font=font(13, lang))
        y += 54
    d.text((pop[0] + 22, y + 8), shape(ui["recent"], lang), fill=(20, 20, 20), font=font(15, lang))
    y += 40
    for row in ui["recent_rows"]:
        round_rect(d, (pop[0] + 16, y, pop[2] - 16, y + 44), 8, fill=(255, 255, 255))
        d.text((pop[0] + 28, y + 12), shape(row, lang), fill=(30, 30, 30), font=font(13, lang))
        y += 54
    return img


SHOT_RENDERERS = {
    "gallery": mock_shot_gallery,
    "editor": mock_shot_editor,
    "redact": mock_shot_redact,
    "smart": mock_shot_smart,
    "qr": mock_shot_qr,
    "menubar": mock_shot_menubar,
}
CLIP_RENDERERS = {
    "history": mock_clip_history,
    "tags": mock_clip_tags,
    "favorites": mock_clip_favorites,
    "qr": mock_clip_qr,
    "detail": mock_clip_detail,
    "menubar": mock_clip_menubar,
}


def round_corners(image: Image.Image, radius: int) -> Image.Image:
    """Clip to rounded corners while preserving any existing capture alpha."""
    img = image.convert("RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=radius, fill=255)
    # Keep the more transparent of capture-alpha vs rounded mask (min alpha).
    r, g, b, a = img.split()
    a = ImageChops.darker(a, mask)
    return Image.merge("RGBA", (r, g, b, a))


def fit_within(image: Image.Image, max_w: int, max_h: int) -> Image.Image:
    """Scale down to fit inside max box, preserving aspect ratio (never stretch)."""
    w, h = image.size
    if w <= 0 or h <= 0:
        return image
    scale = min(max_w / w, max_h / h, 1.0)
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    if (nw, nh) == (w, h):
        return image
    return image.resize((nw, nh), Image.Resampling.LANCZOS)


def drop_shadow_for(
    ui: Image.Image,
    *,
    offset: tuple[int, int] = (0, 26),
    blur: int = 40,
    opacity: int = 180,
) -> tuple[Image.Image, int]:
    """Soft shadow shaped like the screenshot alpha (no black corner wedges)."""
    ui = ui.convert("RGBA")
    w, h = ui.size
    alpha = ui.split()[-1]
    # Scale capture alpha down to the desired shadow strength.
    shadow_alpha = alpha.point(lambda a: int(a * opacity / 255) if a else 0)
    shadow_rgb = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow_rgb.putalpha(shadow_alpha)

    pad = blur * 2 + max(abs(offset[0]), abs(offset[1])) + 8
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    canvas.paste(shadow_rgb, (pad + offset[0], pad + offset[1]), shadow_rgb)
    return canvas.filter(ImageFilter.GaussianBlur(blur)), pad


def compose_banner(
    raw: Image.Image,
    title: str,
    desc: str,
    lang: str,
    colors: dict,
    *,
    feature_id: Optional[str] = None,
    app: Optional[str] = None,
) -> Image.Image:
    bg = gradient((BANNER_W, BANNER_H), colors)
    # soft light orb
    orb = Image.new("RGBA", (BANNER_W, BANNER_H), (0, 0, 0, 0))
    od = ImageDraw.Draw(orb)
    od.ellipse((BANNER_W - 520, -120, BANNER_W + 80, 480), fill=(*colors["bot"], 90))
    od.ellipse((-160, BANNER_H - 420, 420, BANNER_H + 80), fill=(*colors["top"], 70))
    bg = Image.alpha_composite(bg.convert("RGBA"), orb)
    d = ImageDraw.Draw(bg)

    rtl = lang == "ar"
    title_f = font(58, lang)
    desc_f = font(26, lang)
    t = shape(title, lang)
    ds = shape(desc, lang)

    # text block
    pad = 52
    text_bottom = 130
    if rtl:
        tw = d.textlength(t, font=title_f)
        d.text((BANNER_W - pad - tw, 36), t, fill=(255, 255, 255), font=title_f)
        max_w = BANNER_W - pad * 2
        words = ds.split(" ")
        lines, cur = [], ""
        for w in words:
            trial = (cur + " " + w).strip() if cur else w
            if d.textlength(trial, font=desc_f) <= max_w:
                cur = trial
            else:
                if cur:
                    lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        y = 108
        for line in lines[:3]:
            lw = d.textlength(line, font=desc_f)
            d.text((BANNER_W - pad - lw, y), line, fill=(255, 255, 255), font=desc_f)
            y += 34
        text_bottom = y
    else:
        d.text((pad, 36), t, fill=(255, 255, 255), font=title_f)
        max_w = BANNER_W - pad * 2
        words = ds.split(" ")
        lines, cur = [], ""
        for w in words:
            trial = (cur + " " + w).strip() if cur else w
            if d.textlength(trial, font=desc_f) <= max_w:
                cur = trial
            else:
                if cur:
                    lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        y = 108
        for line in lines[:3]:
            d.text((pad, y), line, fill=(255, 255, 255), font=desc_f)
            y += 34
        text_bottom = y

    # Fit screenshot into remaining space — keep original aspect ratio.
    # Preserve alpha from window captures (transparent corners); never flatten to RGB first.
    margin_x = 72
    margin_bottom = 56
    max_ui_w = BANNER_W - margin_x * 2
    max_ui_h = BANNER_H - text_bottom - 28 - margin_bottom
    ui = fit_within(raw.convert("RGBA"), max_ui_w, max_ui_h)

    # Soft round mask on top of capture alpha so any leftover opaque corner pixels are clipped.
    corner_r = max(14, min(28, ui.width // 36))
    ui = round_corners(ui, corner_r)

    ux = (BANNER_W - ui.width) // 2
    uy = text_bottom + 18 + max(0, (max_ui_h - ui.height) // 2)

    shadow, shadow_pad = drop_shadow_for(ui, offset=(0, 26), blur=40, opacity=180)
    sx = ux - shadow_pad
    sy = uy - shadow_pad
    out = bg.copy()
    out.alpha_composite(shadow, (sx, sy))
    out.alpha_composite(ui, (ux, uy))
    out = paste_buddy_mascot(out, app=app, feature_id=feature_id, ui_box=(ux, uy, ux + ui.width, uy + ui.height))
    return out.convert("RGB")


MASCOT_DIR = ROOT / "shared-buddy/docs/marketing/mascot"

# Buddy placements: (mascot_file, scale_vs_banner_h, anchor) where anchor is relative to UI box.
# Empty = no mascot overlays on App Store banners.
SHOT_BUDDY: dict[str, tuple[str, float, str]] = {}


def paste_buddy_mascot(
    banner: Image.Image,
    *,
    app: Optional[str],
    feature_id: Optional[str],
    ui_box: tuple[int, int, int, int],
) -> Image.Image:
    """Overlay Buddy interacting with the framed UI (Screenshot Buddy banners)."""
    if app != "screenshot-buddy" or not feature_id:
        return banner
    cfg = SHOT_BUDDY.get(feature_id)
    if not cfg:
        return banner
    name, scale, anchor = cfg
    path = MASCOT_DIR / name
    if not path.exists():
        return banner
    buddy = Image.open(path).convert("RGBA")
    target_h = max(120, int(BANNER_H * scale))
    ratio = target_h / buddy.height
    buddy = buddy.resize((max(1, int(buddy.width * ratio)), target_h), Image.Resampling.LANCZOS)

    ux0, uy0, ux1, uy1 = ui_box
    # Sit Buddy on the UI frame, slightly overlapping so he "touches" the content.
    if anchor == "br":
        bx = ux1 - int(buddy.width * 0.72)
        by = uy1 - int(buddy.height * 0.88)
    elif anchor == "bl":
        bx = ux0 - int(buddy.width * 0.18)
        by = uy1 - int(buddy.height * 0.88)
    else:
        bx = ux1 - buddy.width
        by = uy1 - buddy.height

    # Keep Buddy inside the banner with a small margin.
    bx = max(12, min(bx, BANNER_W - buddy.width - 12))
    by = max(8, min(by, BANNER_H - buddy.height - 8))

    out = banner.copy()
    # Soft contact shadow under Buddy.
    shadow = Image.new("RGBA", buddy.size, (0, 0, 0, 0))
    alpha = buddy.split()[-1].point(lambda a: int(a * 0.35) if a else 0)
    shadow.putalpha(alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    out.alpha_composite(shadow, (bx, by + 10))
    out.alpha_composite(buddy, (bx, by))
    return out


def write_mock_content():
    shot_mock = ROOT / "screenshot-buddy/docs/screenshots/mock-content.md"
    clip_mock = ROOT / "clipboard-buddy/docs/screenshots/mock-content.md"
    shot_mock.write_text(
        """# Screenshot Buddy — mock content for store shots

Use this sample gallery when capturing UI:

| Title | Tags | Notes |
|-------|------|-------|
| Login form | password, url | Password field visible for Auto-blur demo |
| Dashboard chart | amount, text | Nexora HR dashboard — gallery hero |
| Demo payslip | amount, iban, email | Annotated Quick edit hero |
| Invoice PDF | amount, iban | IBAN line for redaction |
| Invite poster | qr | Contains scannable QR |
| Brand palette | colorHex | For color picker |
| Meeting notes | text | Menu bar recent list |

Sensitive unlock should be locked so blurred rows appear in gallery + menu bar.
""",
        encoding="utf-8",
    )
    clip_mock.write_text(
        """# Clipboard Buddy — mock content for store shots

Seed history with:

| Preview | Tags | Favorite? |
|---------|------|-----------|
| https://docs.buddy.app | url | yes (Support link) |
| Meeting agenda draft | text | no |
| #10B981 | colorHex | yes (Brand green) |
| •••••••••••• (password) | password | no |
| NL91 ABNA 0417 1643 00 | iban | no |
| sk_live_51Hq… | apiKey | no |
| Release notes draft | text, richText | no |
| https://buddy.app/share/42 | url | for QR sheet |

Enable require-auth for password/iban/apiKey so blur + unlock UI shows.
""",
        encoding="utf-8",
    )


def frame_existing(app: str, features: dict, colors: dict, out_root: Path):
    """Compose banners from real `raw/*.png` captures without regenerating mocks."""
    for lang in LANGS:
        raw_dir = out_root / lang / "raw"
        ban_dir = out_root / lang / "banners"
        ban_dir.mkdir(parents=True, exist_ok=True)
        for fid, meta in features.items():
            raw_path = raw_dir / f"{fid}.png"
            if not raw_path.exists():
                print(f"SKIP missing {raw_path}")
                continue
            raw = Image.open(raw_path)
            if raw.mode != "RGBA":
                raw = raw.convert("RGBA")
            banner = compose_banner(
                raw,
                meta["titles"][lang],
                meta["descs"][lang],
                lang,
                colors,
                feature_id=fid,
                app=app,
            )
            ban_path = ban_dir / f"{fid}.png"
            banner.save(ban_path, optimize=True)
            print(f"framed {app}/{lang}/{fid}")


def generate_app(app: str, features: dict, renderers: dict, colors: dict, out_root: Path):
    for lang in LANGS:
        raw_dir = out_root / lang / "raw"
        ban_dir = out_root / lang / "banners"
        raw_dir.mkdir(parents=True, exist_ok=True)
        ban_dir.mkdir(parents=True, exist_ok=True)
        for fid, meta in features.items():
            ui = meta["ui"][lang]
            raw = renderers[fid](lang, colors, ui)
            raw_path = raw_dir / f"{fid}.png"
            ban_path = ban_dir / f"{fid}.png"
            raw.save(raw_path, optimize=True)
            banner = compose_banner(
                raw,
                meta["titles"][lang],
                meta["descs"][lang],
                lang,
                colors,
                feature_id=fid,
                app=app,
            )
            banner.save(ban_path, optimize=True)
            print(f"{app}/{lang}/{fid}")


def main():
    import sys

    frame_only = "--frame-only" in sys.argv
    write_mock_content()
    if frame_only:
        frame_existing(
            "screenshot-buddy",
            SHOT_FEATURES,
            SHOT_COLORS,
            ROOT / "screenshot-buddy/docs/screenshots",
        )
        frame_existing(
            "clipboard-buddy",
            CLIP_FEATURES,
            CLIP_COLORS,
            ROOT / "clipboard-buddy/docs/screenshots",
        )
    else:
        print("Generating PIL mock raws. Use --frame-only to frame real captures.")
        generate_app(
            "screenshot-buddy",
            SHOT_FEATURES,
            SHOT_RENDERERS,
            SHOT_COLORS,
            ROOT / "screenshot-buddy/docs/screenshots",
        )
        generate_app(
            "clipboard-buddy",
            CLIP_FEATURES,
            CLIP_RENDERERS,
            CLIP_COLORS,
            ROOT / "clipboard-buddy/docs/screenshots",
        )
    print("Done.")


if __name__ == "__main__":
    main()
