// IMETENGENEZWA KWA SCRIPT (gen_help_dart.py) kutoka chanzo kimoja na Mwongozo wa Mtumiaji (PDF).
// Ukibadilisha maandishi hapa, badilisha pia kwenye mwongozo ili yalingane.

/// Sehemu ya msaada: kichwa na hatua.
class HelpSection {
  final String title;
  final List<String> steps;

  const HelpSection(this.title, this.steps);
}

/// Msaada wa ukurasa / fomu moja.
class HelpTopic {
  final String title;
  final String intro;
  final List<HelpSection> sections;
  final List<String> tips;

  const HelpTopic({required this.title, required this.intro, this.sections = const [], this.tips = const []});
}

/// Mpangilio wa mada kwenye kituo cha msaada (Msaada -> mada zote).
const List<String> helpOrder = [
  'dashboard',
  'customers',
  'customerDetail',
  'invoices',
  'invoiceDetail',
  'invoiceSms',
  'boxes',
  'boxDetail',
  'store',
  'overdue',
  'delivery',
  'claims',
  'expenses',
  'cashup',
  'reports',
  'sms',
  'smsBalance',
  'quotations',
  'boxEta',
  'forgotPassword',
  'broadcast',
  'users',
  'roles',
  'permissions',
  'audit',
  'settings',
  'track',
  'changePassword',
  'formProduct',
  'formPayment',
  'formDiscount',
  'formRefund',
  'formHandover',
  'formReceiver',
  'formCustomer',
  'formExpense',
  'formBox',
  'formClaim',
  'formUser',
  'formRate',
];

const Map<String, HelpTopic> helpSw = {
  'dashboard': HelpTopic(
    title: 'Dashibodi',
    intro: 'Ukurasa wa kwanza unaoonyesha hali ya biashara kwa leo: mizigo iko hatua gani, malipo, madeni na kazi zinazosubiri.',
    sections: [
      HelpSection('Unachoona', [
        'Mtiririko wa mzigo: idadi ya ankara kwenye kila hatua (Ankara → Upakiaji → Safarini → Stoo → Imekabidhiwa). Bonyeza hatua kuona ankara zake.',
        'Kadi za takwimu: madeni yote, malipo ya leo na ya mwezi, mapato ya stoo ya mwezi, mizigo iliyochelewa stoo, matumizi ya mwezi, wateja, mabox na SMS zinazosubiri.',
        'Chati ya mapato ya siku 7 na ankara za karibuni.',
        'Chati za pie (mwezi huu): ankara kwa hali, mapato (usafirishaji / stoo), mizigo kwa usafiri, malipo kwa njia, madeni kwa umri.',
      ]),
      HelpSection('Vitendo vya haraka', [
        'Kitufe "Ankara mpya" (juu kulia au chini kwenye simu) kinaanzisha ankara kwa mteja.',
        'Bonyeza kadi yoyote (mf. "Mizigo iliyochelewa stoo") kwenda moja kwa moja kwenye ukurasa wake.',
        'Kengele 🔔 juu inaonyesha taarifa mpya (malipo, mabox yaliyofika, tahadhari).',
        'Ikoni ya kutafuta mtu (juu) inakuwezesha kuchagua mteja na kufungua dashibodi yake.',
      ]),
    ],
    tips: [
      'Vuta chini (au bonyeza ⟳) kusasisha takwimu.',
      'Unaona kadi za sehemu ulizopewa ruhusa tu.',
    ],
  ),
  'customers': HelpTopic(
    title: 'Wateja',
    intro: 'Orodha ya wateja wote. Kila ankara lazima iwe ya mteja aliyesajiliwa.',
    sections: [
      HelpSection('Kusajili mteja', [
        'Bonyeza "Mteja mpya".',
        'Andika jina kamili. Namba ya simu si lazima. Ya Tanzania iandike kama 0712 345 678 au +255712345678; ya nchi nyingine iandike na code ya nchi, mf. +86 138 1234 5678 (China) au +254 712 345 678 (Kenya). Namba moja haiwezi kuwa ya wateja wawili.',
        'Bonyeza Hifadhi. Mteja anaonekana kwenye orodha mara moja.',
      ]),
      HelpSection('Kutafuta na kuchuja', [
        'Andika jina au namba kwenye kisanduku cha kutafuta.',
        'Tumia vichujio: Wote, Hai, Wamezuiwa.',
      ]),
      HelpSection('Vitendo kwa mteja', [
        'Bonyeza mteja kufungua taarifa zake (ankara, madeni, historia).',
        'Menyu ⋮: Badili, Zuia / Ruhusu, Futa, Ankara mpya, Piga simu.',
        'Mteja aliyezuiwa hawezi kufunguliwa ankara mpya.',
      ]),
    ],
    tips: [
      'Unaweza kuingiza wateja wengi kwa Excel: Mipangilio → Kuingiza data.',
      'Kumtumia mteja ujumbe: fungua mteja → ikoni ya SMS.',
    ],
  ),
  'customerDetail': HelpTopic(
    title: 'Dashibodi ya mteja',
    intro: 'Kila kitu kuhusu mteja mmoja na biashara yote mliyowahi kufanya naye. Fungua kutoka Wateja, kutoka Dashibodi (ikoni ya kutafuta mteja) au Ripoti → Muhtasari → Wateja bora.',
    sections: [
      HelpSection('Vichupo', [
        'Muhtasari: takwimu (ankara, iliyotozwa, imelipwa, deni, stoo, punguzo, katoni, kilo), chati za pie (imelipwa/deni, usafiri, njia za malipo, hali za ankara) na biashara kwa mwezi.',
        'Ankara: kila ankara na mizigo yake (jina, katoni, kilo, track, bei), hali, usafiri, siku za stoo, iliyotozwa, imelipwa na deni.',
        'Malipo: kila malipo na refund - tarehe, risiti, ankara, njia, kiasi, aliyepokea.',
        'Zilizokabidhiwa: nani alichukua mzigo, lini na nani alikabidhi; ikoni ya PDF inafungua hati.',
        'Madai na SMS: madai yote ya mteja na ujumbe wote aliotumiwa.',
      ]),
      HelpSection('Kipindi na taarifa', [
        'Kawaida inaonyesha "Tangu mwanzo". Bonyeza kipindi kuchagua tarehe.',
        'Ikoni ya PDF juu: Taarifa ya mteja (statement) ya kipindi hicho.',
        'Ikoni ya jedwali: Excel yenye karatasi za ankara, mizigo, malipo, makabidhiano na SMS.',
        'Pia: piga simu, tuma ujumbe, ankara mpya, badili/zuia mteja.',
      ]),
    ],
    tips: [
      'Bonyeza ankara, malipo au makabidhiano yoyote kufungua ankara husika.',
      'Andika {jina} kwenye ujumbe - litabadilika kuwa jina la mteja.',
    ],
  ),
  'invoices': HelpTopic(
    title: 'Ankara',
    intro: 'Ankara ni kumbukumbu ya mizigo ya mteja kuanzia China mpaka anapokabidhiwa. Kila ankara ina namba yake (mf. 0000123).',
    sections: [
      HelpSection('Kufungua ankara mpya', [
        'Bonyeza "Ankara mpya" → chagua mteja (au msajili papo hapo).',
        'Ankara inafunguka ukiwa tayari kuongeza bidhaa.',
      ]),
      HelpSection('Kutafuta', [
        'Tafuta kwa namba ya ankara, jina la mteja au simu.',
        '"Tafuta kwa track": skani au andika track number ya bidhaa.',
        'Vichujio vya hali (Wazi, Upakiaji, Safarini, Stoo, Imekabidhiwa ...) na ofisi.',
      ]),
      HelpSection('Ankara zilizozuiwa', [
        'Ankara iliyozuiwa (block) haionekani kwenye kazi za kila siku.',
        'Kichujio cha "Zilizozuiwa" kina kitufe "Futa zote zilizozuiwa" (msimamizi tu).',
      ]),
    ],
    tips: [
      'Hali za ankara zinabadilika zenyewe kadri mzigo unavyosonga.',
    ],
  ),
  'invoiceDetail': HelpTopic(
    title: 'Ankara moja (hatua kwa hatua)',
    intro: 'Juu ya ankara kuna kadi ya "Hatua inayofuata" inayokuambia nini cha kufanya sasa. Fuata hatua hizi:',
    sections: [
      HelpSection('1. Ongeza bidhaa (China)', [
        'Bonyeza "Ongeza bidhaa": maelezo, idadi ya katoni, uzito (kg), track number, usafiri (Ndege/Meli) na picha.',
        'Bei inahesabiwa yenyewe kutoka bei za usafirishaji za Mipangilio.',
        'Lebo za QR: chapisha lebo za kubandika kwenye katoni.',
      ]),
      HelpSection('2. Sajili mpokeaji', [
        'Bonyeza "Sajili mpokeaji": mteja mwenyewe au mtu mwingine, na ofisi ya kuchukulia.',
        'Ankara inahamia "Upakiaji" - bidhaa zake sasa zinaweza kuwekwa kwenye box.',
      ]),
      HelpSection('3. Box na safari', [
        'Kwenye Mabox weka bidhaa kwenye box, kisha "Funga na safirisha".',
        'Mteja anapata SMS ya kusafirishwa. Box likifika, lipokee kwenye Stoo.',
      ]),
      HelpSection('4. Ankara ya malipo na kulipa (Tanzania)', [
        'Mzigo ukifika stoo bonyeza "Tengeneza ankara" (PDF) - deni linafunguliwa.',
        'Pokea malipo: kiasi, njia (benki/simu) na sarafu. Risiti inatolewa (PDF) na SMS inatumwa.',
        'Punguzo: msimamizi anaweza kutoa punguzo lenye sababu. Refund: kurudisha pesa iliyozidi.',
      ]),
      HelpSection('5. Kukabidhi', [
        'Deni likiisha bonyeza "Kabidhi": jina la mchukuaji, simu, kitambulisho, sahihi na picha.',
        'Unaweza kukabidhi sehemu ya mzigo (awamu) - zilizobaki zinabaki stoo.',
        '"Kabidhi kwa mkopo" (ruhusa maalum): mzigo unatoka kabla deni halijaisha - lakini kama deni la mkopo la mteja lingezidi kikomo chake, mfumo unakataa.',
      ]),
      HelpSection('Vitendo vingine', [
        'WhatsApp 💬: tuma ujumbe + picha, picha za mizigo, ankara, risiti au hati ya makabidhiano.',
        'Ripoti tatizo la mzigo (umeharibika/umepotea) → linakwenda Madai.',
        'Zuia / Fungua tena ankara, Futa ankara (kabla ya kusafirishwa).',
      ]),
    ],
    tips: [
      'Siku za stoo: siku 7 za bure, kisha \$3 kwa siku - zinaonekana kwenye muhtasari wa malipo.',
      'Historia ya ankara inaonyesha kila hatua na muda wake.',
    ],
  ),
  'invoiceSms': HelpTopic(
    title: 'SMS ya ankara',
    intro: 'Kitufe cha SMS juu ya ankara kinatuma ujumbe unaoorodhesha kila bidhaa ya ankara hiyo kwa mstari wake.',
    sections: [
      HelpSection('Ujumbe una nini', [
        'Hali ya mzigo (umepokelewa China, safarini, umefika stoo, umekabidhiwa).',
        'Kila bidhaa: maelezo, katoni, kipimo (ndege = kilo; meli/container = CBM na tani), usafiri na bei yake.',
        'Jumla ya katoni, kilo za ndege, CBM na tani za meli, na bei; gharama ya stoo, punguzo, kilicholipwa na deni.',
        'Kama kuna deni, njia za malipo zinaongezwa mwishoni.',
      ]),
      HelpSection('Kutuma', [
        'Chagua mteja, mpokeaji au wote wawili. Kama una ruhusa ya WhatsApp, chagua SMS, WhatsApp au zote.',
        'Unaweza kubadilisha maandishi kabla ya kutuma. Tumia {jina} kuweka jina la mpokeaji.',
        'Chini ya ujumbe unaona idadi ya herufi na SMS ngapi zitatumika kwa kila mtu.',
      ]),
      HelpSection('SMS za moja kwa moja', [
        'SMS ya "mzigo umeondoka" na ya "mzigo umefika stoo" sasa zinaorodhesha kila bidhaa ya ankara, si jumla tu.',
        'Bidhaa zikiwa nyingi kuliko SMS_ITEMS_MAX (kawaida 15), zilizobaki zinajumlishwa kwenye mstari mmoja.',
      ]),
    ],
    tips: [
      'Ujumbe mrefu unagharimu SMS zaidi: angalia idadi ya SMS kabla ya kutuma.',
      'Unahitaji ruhusa ya SMS (Kuongeza).',
    ],
  ),
  'boxes': HelpTopic(
    title: 'Mabox (upakiaji China)',
    intro: 'Box (ndege) au container (meli) linabeba mizigo ya ankara nyingi kwenda Tanzania.',
    sections: [
      HelpSection('Kutengeneza box', [
        'Bonyeza "Box jipya" → chagua Box la ndege (AIR) au Container ya meli (SEA).',
        'Box linaanza kwenye "Upakiaji".',
      ]),
      HelpSection('Kuweka mizigo', [
        'Kompyuta: buruta bidhaa kutoka "Inasubiri kupakiwa" kwenda kwenye box.',
        'Simu: bonyeza bidhaa kwa muda kisha uiburute, au fungua box → chagua bidhaa → "Weka kwenye box".',
        'Unaweza kuskani track number ya bidhaa.',
      ]),
      HelpSection('Kusafirisha', [
        'Fungua box → "Funga na safirisha" → weka uzito wa mwisho na track number ya box (ya kampuni ya usafiri).',
        'Wateja wa mizigo iliyomo wanapata SMS ya kusafirishwa.',
      ]),
    ],
    tips: [
      'Box la ndege linapokea mizigo ya ndege tu; container inapokea ya meli tu.',
      'Ankara lazima iwe na mpokeaji kabla bidhaa zake hazijawekwa kwenye box.',
    ],
  ),
  'boxDetail': HelpTopic(
    title: 'Box moja',
    intro: 'Ndani ya box unaona bidhaa zilizomo na zinazosubiri, na vitendo vya box.',
    sections: [
      HelpSection('Vitendo', [
        'Weka / Ondoa bidhaa kwenye box.',
        'Manifest (PDF): orodha ya mizigo yote ya box.',
        'Lebo za QR za box na za katoni.',
        'Gharama za box (usafiri, ushuru, clearing ...) - zinatumika kwenye ripoti ya Faida.',
        'Funga na safirisha; au Pokea (ukiwa Tanzania).',
      ]),
    ],
    tips: [
      'Box lililofungwa haliwezi kuongezwa mizigo.',
    ],
  ),
  'store': HelpTopic(
    title: 'Stoo (kupokea mabox)',
    intro: 'Hapa unapokea mabox yaliyofika Tanzania. Ukipokea box, mizigo yake yote inaingia stoo na wateja wanapata SMS.',
    sections: [
      HelpSection('Kupokea box', [
        'Kichujio "Yanayotarajiwa" kinaonyesha mabox yaliyo safarini.',
        'Bonyeza "Pokea" kwenye box, au "Skani kupokea" na uskani track number ya box.',
        'Hakiki mizigo kisha thibitisha. Ankara zinahamia hali ya Stoo na siku za stoo zinaanza kuhesabiwa.',
      ]),
      HelpSection('Mizigo iliyochelewa stoo', [
        'Kitufe ⏳ juu (chenye namba) kinafungua orodha ya mizigo iliyokaa zaidi ya siku 7.',
        'Kila baada ya siku 7 utapata dirisha (popup) la kukukumbusha mizigo hii.',
      ]),
    ],
    tips: [
      'Siku 7 za kwanza ni bure; baada ya hapo mteja anatozwa \$3 kwa kila siku.',
    ],
  ),
  'overdue': HelpTopic(
    title: 'Mizigo iliyochelewa stoo',
    intro: 'Orodha ya mizigo iliyokaa stoo zaidi ya siku za bure (7). Kila siku inayozidi inatozwa \$3, ikibadilishwa kuwa TSh kwa kiwango cha USD cha sasa.',
    sections: [
      HelpSection('Unachoona', [
        'Jumla ya mizigo, jumla ya gharama za stoo (TSh na \$) na mzigo uliokaa muda mrefu zaidi.',
        'Kwa kila mzigo: mteja, ankara, siku stoo, siku za kulipia, gharama, deni na lini alikumbushwa mwisho.',
      ]),
      HelpSection('Kumkumbusha mteja', [
        'Mmoja: bonyeza 🔔 kwenye mzigo wake.',
        'Wengi: weka alama ✓ kwenye mizigo, kisha "Kumbusha (n)".',
        'Wote: bila kuchagua, bonyeza "Kumbusha wote".',
        'Chagua SMS, WhatsApp au zote. Ukiacha ujumbe tupu, ujumbe wa kawaida (wenye siku na gharama) unatumwa.',
        'Ujumbe wako unaweza kutumia {jina} {ankara} {siku} {usd} {tsh}.',
      ]),
      HelpSection('Popup ya kila siku 7', [
        'Mfumo unaangalia mizigo hii wenyewe; kukiwa na iliyochelewa, utapata dirisha la tahadhari mara moja kila siku 7.',
        'Bonyeza "Angalia mizigo" kufungua orodha hii.',
      ]),
    ],
    tips: [
      'Malipo ya stoo yanaonekana Ripoti → Mapato (sehemu ya "Stoo") na kwenye Dashibodi.',
      'Pakua Excel ya mizigo iliyochelewa kwa ikoni ya jedwali juu.',
    ],
  ),
  'delivery': HelpTopic(
    title: 'Kukabidhi na malipo',
    intro: 'Ankara za mizigo iliyo stoo: tengeneza ankara ya malipo, pokea malipo na umkabidhi mteja mzigo wake.',
    sections: [
      HelpSection('Kazi ya kila siku', [
        'Mteja akifika, tafuta ankara kwa jina, simu au skani "Code ya kuchukulia" kwenye SMS yake.',
        'Kama haijatengenezwa, bonyeza "Ankara" kutengeneza ankara ya malipo.',
        '"Lipa": weka kiasi na njia ya malipo. Risiti inatoka.',
        'Deni likiisha: "Kabidhi" → jaza taarifa za mchukuaji, sahihi, kisha hifadhi. Hati ya makabidhiano (PDF) inatoka.',
      ]),
      HelpSection('Vichujio', [
        'Zote, Hazijatengenezewa ankara, Zinadaiwa, Zimelipwa.',
      ]),
      HelpSection('Mizigo iliyokabidhiwa (kichupo "Zilizokabidhiwa")', [
        'Inaonyesha kila kukabidhi, pamoja na awamu (sehemu ya mzigo), za karibuni kwanza.',
        'Tafuta kwa mteja, simu, namba ya ankara, mchukuaji, aliyekabidhi, jina la mzigo au track number.',
        'Chuja kwa tarehe (kipindi), usafiri (Ndege / Meli), aliyekabidhi, au zilizotolewa kwa mkopo tu.',
        'Bonyeza mstari kufungua ankara; ikoni ya PDF inafungua hati ya makabidhiano; ikoni ya jedwali inapakua Excel.',
      ]),
    ],
    tips: [
      'Gharama ya stoo inaongezwa yenyewe kwenye deni kila siku baada ya siku 7.',
      'Kiwango cha sarafu kinachukuliwa kutoka Mipangilio → Viwango vya sarafu.',
    ],
  ),
  'claims': HelpTopic(
    title: 'Madai',
    intro: 'Mizigo iliyoharibika, kupotea au kupungua. Dai linafunguliwa kutoka kwenye ankara ("Ripoti tatizo la mzigo").',
    sections: [
      HelpSection('Kufungua dai', [
        'Fungua ankara → Vitendo → "Ripoti tatizo la mzigo".',
        'Chagua aina (Imeharibika / Imepotea / Imepungua), bidhaa, katoni, maelezo na picha.',
      ]),
      HelpSection('Kumaliza dai', [
        'Kwenye Madai fungua dai → "Amua": kubali au kataa, andika uamuzi, na kama kuna fidia chagua Punguzo (kwenye deni) au Refund (pesa inarudishwa).',
      ]),
    ],
    tips: [
      'Vichujio: Wazi, Yamekubaliwa, Yamekataliwa.',
    ],
  ),
  'expenses': HelpTopic(
    title: 'Matumizi',
    intro: 'Matumizi ya ofisi (kodi ya pango, mafuta, mishahara ya vibarua ...). Yanatumika kwenye ripoti ya matumizi na faida ya mwezi.',
    sections: [
      HelpSection('Kuandika matumizi', [
        'Bonyeza "Matumizi mapya" → maelezo, kiasi (TSh) na ofisi → Hifadhi.',
      ]),
      HelpSection('Kurekebisha', [
        'Menyu ⋮ kwenye matumizi → Badili au Futa.',
      ]),
    ],
    tips: [
      'Chuja kwa ofisi na tarehe; jumla inaonekana juu.',
    ],
  ),
  'cashup': HelpTopic(
    title: 'Kufunga hesabu ya siku',
    intro: 'Kila siku jioni mhasibu analinganisha malipo yaliyorekodiwa kwenye mfumo (kwa kila benki / njia) na pesa halisi aliyoihesabu au iliyoingia benki. Tofauti ikiwepo, wasimamizi wanapata taarifa.',
    sections: [
      HelpSection('Kufunga siku', [
        'Fungua Hesabu ya siku → kichupo "Kufunga siku" (kawaida ni leo; bonyeza tarehe kubadili).',
        'Kwa kila njia ya malipo unaona kiasi cha mfumo na idadi ya malipo. Andika kiasi halisi ulichohesabu.',
        'Tofauti inaonekana papo hapo (nyekundu = pungufu, njano = zaidi, kijani = sawa). Andika maelezo kama ipo.',
        'Bonyeza "Funga hesabu ya siku" na uthibitishe. Siku moja inafungwa mara moja tu.',
      ]),
      HelpSection('Baada ya kufunga', [
        'Muhtasari wa siku iliyofungwa unaonekana pamoja na PDF ya hesabu.',
        'Malipo yakiingizwa baada ya kufunga, yanaonyeshwa kama tahadhari.',
        'Msimamizi (ruhusa ya kufuta malipo) anaweza kufungua upya siku ili ifungwe tena.',
        'Kichupo "Historia": siku zote zilizofungwa, jumla ya mapungufu na ziada.',
      ]),
    ],
    tips: [
      'Funga hesabu kila siku kabla ya kuondoka ofisini - inazuia na kugundua upotevu wa pesa mapema.',
    ],
  ),
  'reports': HelpTopic(
    title: 'Ripoti',
    intro: 'Ripoti za biashara kwa kipindi unachochagua - kwenye skrini (chati) na kama PDF au Excel. PDF zote zina takwimu juu, chati za pie/nguzo na jedwali zenye jumla.',
    sections: [
      HelpSection('Vichupo', [
        'Muhtasari: takwimu za kipindi, biashara kwa mwezi (iliyotozwa, malipo, matumizi), pie za usafiri, njia za malipo, matumizi kwa ofisi na wateja bora.',
        'Ripoti za PDF: chagua ripoti, kipindi na vichujio, kisha "Tengeneza ripoti".',
        'Mapato: usafirishaji dhidi ya stoo. Faida: mapato dhidi ya gharama za kila box. Madeni kwa umri. Excel.',
      ]),
      HelpSection('Ripoti za PDF zilizopo', [
        'Muhtasari wa biashara; Taarifa ya mteja (chagua mteja); Wateja bora.',
        'Mapato kwa hali ya deni; Madeni (kwa ankara na kwa mteja, kwa umri).',
        'Mizigo iliyopokelewa; Mabox na faida; Mizigo iliyokabidhiwa - zote zinachujwa kwa usafiri (Ndege/Meli).',
        'Mapato kwa njia za malipo (benki, mfanyakazi, kwa siku); Matumizi (kwa ofisi); Mapato ya stoo.',
      ]),
      HelpSection('Kutumia', [
        'Chagua kipindi (au "Mwezi huu", "Miezi 3", "Mwaka huu").',
        'Bonyeza ikoni ya jedwali kupakua Excel, au ya PDF kupakua/kuchapisha.',
      ]),
    ],
    tips: [
      'Mapato ya stoo = sehemu ya malipo iliyozidi gharama ya usafirishaji ya ankara (hadi gharama ya stoo).',
      'Ripoti zinatengenezwa na server moja kwa moja - hazihitaji Word.',
    ],
  ),
  'sms': HelpTopic(
    title: 'SMS',
    intro: 'Mfumo unatuma SMS zenyewe (mzigo umepokelewa, umesafirishwa, umefika stoo, risiti, vikumbusho). Hapa unaona zinazosubiri, zilizotumwa na zilizoshindikana.',
    sections: [
      HelpSection('Ujumbe mpya kwa wateja', [
        'Bonyeza "Ujumbe mpya" kumtumia mteja mmoja, waliochaguliwa au wote (tazama "Ujumbe kwa wateja").',
      ]),
      HelpSection('Zinazosubiri', [
        '"Tuma" moja moja, "Badili na tuma", au ikoni ya kutuma zote zinazosubiri.',
        'Alama nyekundu ⚠ inaonyesha sababu ya kushindwa (mf. mtandao).',
      ]),
      HelpSection('Vichujio', [
        'Aina: kupokelewa, kusafirishwa, stoo, vikumbusho, risiti, makabidhiano, ujumbe binafsi, WhatsApp.',
        'Zinasubiri / Zimetumwa / Hazikufika.',
      ]),
      HelpSection('Imefika au haikufika', [
        'Kwenye zilizotumwa: "Imefika" (kijani) = imemfikia mteja; "Haikufika" (nyekundu) = gateway imeripoti kushindwa (sababu inaonekana ukishikilia); "Imetumwa" = FastHub imepokea, ripoti bado.',
        '"Hazikufika" inaonyesha zote ambazo hazikumfikia mteja - zirekebishe namba au "Tuma tena".',
        'Ripoti zinahitaji FastHub iwekewe URL ya ripoti (tazama mwongozo wa msimamizi).',
      ]),
      HelpSection('Salio la SMS', [
        'Juu ya ukurasa kuna salio la SMS na matumizi ya mwezi huu.',
        'Ukinunua SMS FastHub, bonyeza "Rekodi SMS zilizonunuliwa". Mara moja moja "Weka salio halisi" kutoka akaunti ya FastHub ili makadirio yawe sahihi.',
        'Salio likishuka chini ya kiwango (kawaida 300) unapata taarifa, na kadi inakuwa nyekundu.',
      ]),
    ],
    tips: [
      'Washa/zima kila aina ya SMS kwenye Mipangilio → Aina za SMS.',
      'SMS ya herufi zaidi ya 160 inahesabiwa kama SMS 2 au zaidi.',
    ],
  ),
  'smsBalance': HelpTopic(
    title: 'Salio la SMS',
    intro: 'Mfumo unafuatilia salio la SMS za FastHub ili zisisimame bila kujua.',
    sections: [
      HelpSection('Kurekodi', [
        '"Rekodi SMS zilizonunuliwa": idadi ya SMS ulizonunua sasa hivi - zinaongezwa kwenye salio.',
        '"Weka salio halisi": salio unaloliona kwenye akaunti ya FastHub - makadirio yanaanzia hapo.',
        'Kila SMS inayotumwa inatoa vipande vyake (SMS ndefu = vipande 2 au zaidi).',
      ]),
      HelpSection('Onyo', [
        'Salio likishuka chini ya SMS_LOW_BALANCE (kawaida 300), wenye ruhusa ya SMS wanapata taarifa kila siku hadi uongeze salio.',
      ]),
    ],
    tips: [
      'Kama FastHub inatoa URL ya kuuliza salio, msimamizi wa server anaweza kuiweka (SMS_BALANCE_API) na salio litaonekana moja kwa moja.',
    ],
  ),
  'quotations': HelpTopic(
    title: 'Makadirio ya bei',
    intro: 'Mteja akiuliza "mzigo huu utagharimu kiasi gani?" kabla haujapokelewa, tengeneza makadirio, mtumie kwa SMS au PDF, na akikubali yageuze kuwa ankara.',
    sections: [
      HelpSection('Kutengeneza', [
        '"Makadirio mapya": chagua mteja aliyepo au andika jina na simu ya mteja mpya.',
        'Kwa kila bidhaa: maelezo, usafiri, katoni na kipimo. Ndege = kilo. Meli (container) = CBM (na kilo kwa ajili ya tani).',
        'Bei inahesabiwa yenyewe kwa bei za Mipangilio. Unaweza kuandika kiasi kwa mkono; "Hesabu upya" kurudi kwenye bei ya mfumo.',
        'Chagua muda wa kuwa halali (siku 7 hadi 60).',
      ]),
      HelpSection('Kutuma na kufuatilia', [
        'PDF ya kuchapisha au kutuma; SMS/WhatsApp inaorodhesha kila bidhaa na jumla.',
        'Hali: Rasimu → Yametumwa → Amekubali / Amekataa → Imekuwa ankara. Muda ukipita yanaonyesha "Muda umeisha".',
      ]),
      HelpSection('Kugeuza kuwa ankara', [
        '"Geuza kuwa ankara": ankara mpya inaundwa na bidhaa zote; mteja anasajiliwa kama hayupo.',
        'Mzigo ukipokelewa, rekebisha uzito, track number na picha kwenye ankara kama kawaida.',
      ]),
    ],
    tips: [
      'Makadirio si deni - deni linaanza ankara inapotengenezwa stoo.',
      'Ruhusa: Makadirio ya bei (Kuona, Kuongeza, Kubadili, Kufuta).',
    ],
  ),
  'boxEta': HelpTopic(
    title: 'Tarehe ya kutarajia kufika (ETA)',
    intro: 'Kila box linalosafirishwa lina tarehe ya kutarajia kufika Tanzania.',
    sections: [
      HelpSection('Inavyowekwa', [
        'Unapofunga box unaweza kuchagua ETA; usipochagua, mfumo unaweka siku za kawaida (ndege 10, meli 45).',
        'ETA inaonekana kwenye SMS ya "mzigo umeondoka", kwenye ukurasa wa kufuatilia mzigo, kwenye Mabox na Stoo.',
      ]),
      HelpSection('Box likichelewa', [
        'ETA ikipita kabla box halijapokelewa, linaonyesha "Imechelewa siku N" (nyekundu) na wenye ruhusa ya Stoo wanapata taarifa kila asubuhi.',
        'Dashibodi inaonyesha idadi ya mabox yaliyochelewa.',
        'Kubadilisha: fungua box → kadi ya ETA → chagua tarehe mpya. Washa "Wajulishe wateja" kutuma SMS yenye tarehe mpya na sababu.',
      ]),
    ],
    tips: [
      'Siku za kawaida zinabadilishwa kwenye server: ETA_AIR_DAYS na ETA_SEA_DAYS.',
    ],
  ),
  'forgotPassword': HelpTopic(
    title: 'Umesahau nywila',
    intro: 'Kwenye skrini ya kuingia bonyeza "Umesahau nywila?".',
    sections: [
      HelpSection('Hatua', [
        'Andika jina lako la mtumiaji au namba yako ya simu, bonyeza "Tuma code".',
        'Code ya tarakimu 6 inatumwa kwa SMS kwenye namba yako iliyosajiliwa (inaisha baada ya dakika chache).',
        'Andika code na nywila mpya (angalau herufi 8, zenye herufi na namba), kisha ingia kwa nywila mpya.',
      ]),
    ],
    tips: [
      'Kama code haikutumwa, sababu inaonyeshwa (mf. akaunti haina namba ya simu, au SMS imekataliwa na FastHub).',
      'Kama huna namba ya simu kwenye akaunti, msimamizi ndiye atakuwekea nywila mpya.',
      'Ukibadilisha nywila, umetolewa kwenye vifaa vingine vyote.',
    ],
  ),
  'broadcast': HelpTopic(
    title: 'Ujumbe kwa wateja',
    intro: 'Tuma ujumbe wako mwenyewe kwa SMS, WhatsApp au zote - kwa mteja mmoja, waliochaguliwa au wote.',
    sections: [
      HelpSection('1. Chagua walengwa', [
        'Wote: wateja wote walio hai.',
        'Waliochaguliwa: bonyeza "Chagua wateja", tafuta na uweke alama ✓.',
        'Mmoja: chagua mteja, au andika namba yoyote ya simu: ya Tanzania (0712... / +255...) au ya nchi nyingine yenye code ya nchi (+86..., +254...), na jina (si lazima).',
        'Wenye mzigo stoo / Waliochelewa stoo / Wanaodaiwa: makundi yanayojijaza yenyewe.',
      ]),
      HelpSection('2. Andika ujumbe', [
        'Andika ujumbe. Bonyeza "Weka jina" kuweka {jina} - kila mteja ataona jina lake.',
        'Tumia mifano iliyoandaliwa (mzigo umefika, sikukuu, malipo, bei mpya) kisha urekebishe.',
        'Kipimo kinaonyesha herufi na idadi ya SMS (160 = SMS 1).',
      ]),
      HelpSection('3. Tuma', [
        'Chagua SMS / WhatsApp / Zote.',
        '"Angalia walengwa" kuona idadi, SMS zitakazotumika na mfano wa ujumbe.',
        '"Tuma" → thibitisha. Zima "Tuma sasa hivi" kama unataka zibaki kwenye SMS → Zinasubiri.',
      ]),
    ],
    tips: [
      'Ujumbe binafsi unaonekana kwenye SMS kwa aina "Ujumbe binafsi".',
      'Kila namba inapata ujumbe mmoja tu hata kama ina ankara nyingi.',
    ],
  ),
  'users': HelpTopic(
    title: 'Watumiaji',
    intro: 'Watu wanaotumia mfumo. Kila mtumiaji ana jukumu (role) linaloamua anaona na kufanya nini.',
    sections: [
      HelpSection('Kuongeza mtumiaji', [
        '"Mtumiaji mpya": jina, simu, username, ofisi na jukumu.',
        'Nywila ya muda inaonyeshwa - mpe mtumiaji. Ataombwa kuibadilisha akiingia mara ya kwanza.',
      ]),
      HelpSection('Vitendo', [
        'Badili, Zuia / Ruhusu, Weka nywila mpya, Toa nje kila mahali, Futa.',
        'Ruhusa maalum: badili ruhusa za mtu mmoja bila kubadili jukumu lake.',
        'Washa uthibitisho wa hatua mbili (2FA): kila akiingia, baada ya nywila atatumiwa code ya tarakimu 6 kwa SMS. Inapendekezwa kwa Msimamizi na Mhasibu (lazima awe na namba sahihi ya simu).',
        '"Ofisi zote": mtumiaji akizimiwa anaona data ya ofisi yake tu.',
      ]),
    ],
    tips: [
      'Usishiriki akaunti moja na watu wawili - kumbukumbu zinaonyesha nani alifanya nini.',
    ],
  ),
  'roles': HelpTopic(
    title: 'Majukumu (roles)',
    intro: 'Jukumu ni kundi la ruhusa. Mfumo una majukumu ya awali: Msimamizi, Mpokeaji China, Stoo Tanzania, Mhasibu, Mtazamaji.',
    sections: [
      HelpSection('Kutumia', [
        '"Jukumu jipya" au badili lililopo: chagua moduli na vitendo vyake. Kila moduli inaonyesha maelezo mafupi ya inachoruhusu.',
        'Vitendo visivyo na maana kwa moduli fulani vinaonyeshwa kama "—" (mf. Punguzo lina "Kuongeza" tu).',
        'Bonyeza jina la moduli kuwasha au kuzima vitendo vyake vyote.',
        '"Tumia kwa watumiaji wake": ruhusa mpya zinawekwa kwa wote wenye jukumu hilo.',
      ]),
      HelpSection('Majukumu ya awali yanaruhusu nini', [
        'Msimamizi: kila kitu.',
        'Mpokeaji China: wateja, ankara, mizigo, mabox, SMS na WhatsApp. Haoni pesa.',
        'Stoo Tanzania: stoo, kukabidhi mizigo (si kwa mkopo), madai, SMS na WhatsApp. Haoni pesa za wateja.',
        'Mhasibu: malipo, punguzo, marejesho, matumizi, kufunga hesabu ya siku, ripoti, faida na pesa kwenye dashibodi. Hawezi kufungua upya hesabu iliyofungwa.',
        'Mtazamaji: anaona tu, bila pesa, ripoti za pesa, faida, kumbukumbu za ukaguzi wala backup.',
      ]),
    ],
    tips: [
      'Jukumu la mfumo haliwezi kufutwa.',
      'Toa ruhusa ndogo kwanza; ongeza mtu anapohitaji.',
    ],
  ),
  'permissions': HelpTopic(
    title: 'Ruhusa',
    intro: 'Ruhusa za mtumiaji mmoja kwa kila moduli. Kila moduli inaonyesha vitendo vyenye maana kwake tu.',
    sections: [
      HelpSection('Kutumia', [
        'Washa au zima kila kitendo; "Ruhusu zote" / "Ondoa zote" kwa haraka.',
        'Mabadiliko yanaanza mara moja.',
      ]),
      HelpSection('Ruhusa za kina', [
        'Pesa kwenye dashibodi: bila hii, dashibodi inaonyesha idadi tu (ankara, mabox, mizigo) bila kiasi cha pesa.',
        'Pesa (ripoti na wateja): bila hii, ripoti za mapato, madeni, matumizi na muhtasari hazionekani, na taarifa za mteja hazionyeshi malipo, salio wala taarifa ya akaunti. Ripoti za mizigo, makabidhiano na stoo zinabaki.',
        'Bei na viwango vya fedha: Kuona = kuchagua bei wakati wa kuandika ankara; Kuongeza = kuweka bei au kiwango kipya. Mipangilio peke yake haitoshi tena.',
        'Kukabidhi mizigo: Kuongeza = kukabidhi iliyolipwa; Kubadili = kukabidhi kwa mkopo.',
        'Punguzo, Kurudisha pesa, Kikomo cha mkopo: kila moja ni ruhusa yake, si sehemu ya Malipo tena.',
        'Madai: Kuongeza = kuripoti; Kubadili = kuamua (kulipa fidia au kukataa).',
        'Kufunga hesabu ya siku: Kuongeza = kufunga; Futa = kufungua upya.',
        'Ujumbe kwa wateja wengi: bila hii, mtumiaji anaweza kumtumia mteja mmoja tu. Inahitajika pia kuendesha vikumbusho vya madeni na kuwakumbusha wote wenye mizigo iliyokaa stoo.',
        'WhatsApp, Faida na gharama za box, Kumbukumbu za ukaguzi, Backup, Kuingiza Excel, Makadirio ya bei: kila moja ina ruhusa yake.',
      ]),
    ],
    tips: [
      'Kwa watu wengi wenye kazi moja, tumia Majukumu badala ya ruhusa moja moja.',
      'Mtu akiona "huna ruhusa" ni kwamba ruhusa hiyo haijawashwa kwake.',
    ],
  ),
  'audit': HelpTopic(
    title: 'Kumbukumbu (audit)',
    intro: 'Kila badiliko kwenye mfumo linaandikwa: nani, nini, lini na kutoka wapi.',
    sections: [
      HelpSection('Kutafuta', [
        'Tafuta kwa jina, kitendo au data.',
        'Chuja kwa moduli, tarehe au zilizoshindikana tu.',
        'Bonyeza "Pakia zaidi" kwa za zamani.',
      ]),
    ],
    tips: [
      'Kumbukumbu haziwezi kubadilishwa wala kufutwa na mtumiaji.',
    ],
  ),
  'settings': HelpTopic(
    title: 'Mipangilio',
    intro: 'Akaunti yako, mwonekano wa app na mipangilio ya biashara.',
    sections: [
      HelpSection('Akaunti na mwonekano', [
        'Badili nywila, lugha (Kiswahili/English), mandhari (mwanga/giza), toka nje.',
      ]),
      HelpSection('Biashara', [
        'Viwango vya sarafu (USD, RMB ...): kiwango cha TSh kinachotumika kwenye malipo na gharama ya stoo.',
        'Bei za usafirishaji: bei kwa kg (au CBM) kwa ndege na meli.',
        'Benki / njia za malipo, Ofisi.',
      ]),
      HelpSection('Aina za SMS (washa / zima)', [
        'Kila SMS inayotumwa na mfumo ina swichi yake: kupokelewa, kusafirishwa, kufika stoo, risiti, makabidhiano, vikumbusho vya deni, onyo la stoo, mizigo iliyochelewa stoo, tarehe ya kufika (ETA), ujumbe kwa wateja, SMS ya ankara, makadirio ya bei, code ya kuingia (2FA), code ya kusahau nywila, tahadhari za mfumo na nakala za WhatsApp.',
        'Aina iliyozimwa haitumwi kabisa. SMS za mkono (ujumbe kwa wateja, SMS ya ankara, makadirio...) zinaonyesha ujumbe kwamba aina hiyo imezimwa.',
        'Ukizima "Code ya kuingia (2FA)", 2FA inasimamishwa: wenye 2FA wanaingia kwa nywila tu hadi uiwashe tena.',
        'Ukizima "Code ya kusahau nywila", msimamizi ndiye anaweka nywila mpya kwa watumiaji.',
      ]),
      HelpSection('Mfumo', [
        'Hali ya mfumo: database, SMS, WhatsApp, nakala (backup) na kazi zinazojiendesha.',
        'Backup: tengeneza na pakua nakala ya data.',
        'Kuingiza data kwa Excel: wateja na madeni ya zamani (pakua kiolezo kwanza).',
      ]),
    ],
    tips: [
      'Badili kiwango cha USD kila kinapobadilika - gharama ya stoo inakitumia.',
    ],
  ),
  'track': HelpTopic(
    title: 'Kufuatilia mzigo (kwa mteja)',
    intro: 'Mteja anaweza kuangalia mzigo wake bila kuingia kwenye mfumo, kwa kiungo kilicho kwenye SMS au ukurasa wa "Fuatilia mzigo".',
    sections: [
      HelpSection('Kutumia', [
        'Andika track number au code ya kuchukulia → "Tafuta".',
        'Anaona hatua ya mzigo, siku za stoo zilizobaki bure, gharama ya stoo na deni.',
      ]),
    ],
    tips: [
      'Majaribio mengi mfululizo yanazuiwa kwa muda kwa usalama.',
    ],
  ),
  'changePassword': HelpTopic(
    title: 'Kubadili nywila',
    intro: 'Nywila mpya lazima iwe na herufi 8 au zaidi, ikiwa na herufi na namba.',
    sections: [
      HelpSection('Hatua', [
        'Andika nywila ya sasa (au ya muda uliyopewa).',
        'Andika nywila mpya mara mbili → Hifadhi.',
        'Vifaa vingine ulivyoingia vinatolewa nje.',
      ]),
      HelpSection('Kuingia kwa code ya SMS (2FA)', [
        'Kama msimamizi amekuwashia 2FA, baada ya nywila utatumiwa code ya tarakimu 6 kwa SMS.',
        'Andika code (inaisha baada ya dakika 5). Haijafika? Bonyeza "Tuma code tena" baada ya sekunde 45.',
        '"Nikumbuke": weka alama ubaki umeingia; usiweke kwenye kifaa cha watu wengi.',
      ]),
    ],
    tips: [
      'Ukisahau nywila, mwombe msimamizi akuwekee nywila mpya ya muda.',
    ],
  ),
  'formProduct': HelpTopic(
    title: 'Fomu: Bidhaa',
    intro: 'Kila mzigo ulioletwa na mteja China.',
    sections: [
      HelpSection('Sehemu', [
        'Maelezo: aina ya bidhaa (mf. Viatu).',
        'Katoni: idadi ya katoni.',
        'Uzito (kg) - au CBM kwa meli.',
        'Track number: ya kampuni iliyoleta mzigo stoo ya China.',
        'Usafiri: Ndege au Meli.',
        'Picha: piga picha ya mzigo (inasaidia kwenye madai).',
      ]),
    ],
    tips: [
      'Bei inajihesabu kutoka bei za usafirishaji; unaweza kuibadilisha kama una ruhusa.',
    ],
  ),
  'formPayment': HelpTopic(
    title: 'Fomu: Kupokea malipo',
    intro: 'Kila malipo yanapunguza deni na kutoa risiti.',
    sections: [
      HelpSection('Sehemu', [
        'Kiasi na sarafu (TSh au USD ...): kwa sarafu nyingine kiasi kinabadilishwa kwa kiwango cha sasa.',
        'Njia ya malipo (benki / simu).',
        'Maelezo (si lazima): mf. namba ya muamala.',
      ]),
    ],
    tips: [
      'Kiasi hakiwezi kuzidi deni lililobaki.',
      'Deni likiisha, mzigo uko tayari kukabidhiwa.',
      'Kosa la kiasi? Tumia Refund kurekebisha - malipo hayafutwi.',
    ],
  ),
  'formDiscount': HelpTopic(
    title: 'Fomu: Punguzo',
    intro: 'Punguzo linapunguza jumla ya ankara (pamoja na stoo).',
    sections: [
      HelpSection('Sehemu', [
        'Kiasi cha punguzo (TSh).',
        'Sababu (lazima) - inaonekana kwenye ankara na kumbukumbu.',
      ]),
    ],
    tips: [
      'Ruhusa ya punguzo ni ya msimamizi/mhasibu tu.',
    ],
  ),
  'formRefund': HelpTopic(
    title: 'Fomu: Refund',
    intro: 'Kurudisha pesa kwa mteja (mf. alilipa zaidi au dai limekubaliwa).',
    sections: [
      HelpSection('Sehemu', [
        'Kiasi (hakiwezi kuzidi kilicholipwa).',
        'Njia ya kurudisha na sababu.',
      ]),
    ],
    tips: [
      'Refund inapunguza "Imelipwa" na inaonekana kwenye ripoti ya malipo kama hasi.',
    ],
  ),
  'formHandover': HelpTopic(
    title: 'Fomu: Kukabidhi mzigo',
    intro: 'Kumbukumbu ya nani alichukua mzigo.',
    sections: [
      HelpSection('Sehemu', [
        'Jina la mchukuaji, simu (si lazima; Tanzania au +code ya nchi), aina na namba ya kitambulisho.',
        'Katoni za kukabidhi (kwa awamu) - acha zote kukabidhi kila kitu.',
        'Sahihi ya mchukuaji (chora kwenye kisanduku) na picha (si lazima).',
      ]),
    ],
    tips: [
      'Hati ya makabidhiano (PDF) inaweza kutumwa kwa WhatsApp.',
    ],
  ),
  'formReceiver': HelpTopic(
    title: 'Fomu: Mpokeaji',
    intro: 'Nani atachukua mzigo Tanzania na ofisi gani.',
    sections: [
      HelpSection('Sehemu', [
        'Mtumaji mwenyewe au mtu mwingine (jina, na simu si lazima: Tanzania au +code ya nchi).',
        'Ofisi ya kuchukulia.',
      ]),
    ],
    tips: [
      'Baada ya hapa ankara inaingia kwenye Upakiaji.',
    ],
  ),
  'formCustomer': HelpTopic(
    title: 'Fomu: Mteja',
    intro: 'Taarifa za mteja.',
    sections: [
      HelpSection('Sehemu', [
        'Jina kamili.',
        'Namba ya simu (si lazima): Tanzania 0712 345 678 / +255712345678, au nchi nyingine na code yake, mf. +8613812345678. SMS na WhatsApp zinatumwa hapa.',
        'Kikomo cha mkopo (TSh, si lazima): kiasi cha juu cha deni la mizigo iliyotoka kwa mkopo. Tupu = kikomo cha kawaida cha mfumo; 0 = hakopeshwi kabisa.',
      ]),
    ],
    tips: [
      'Namba moja kwa mteja mmoja tu.',
      'Mteja asiye na namba hapati SMS - mpigie au mpe taarifa ofisini.',
    ],
  ),
  'formExpense': HelpTopic(
    title: 'Fomu: Matumizi',
    intro: 'Matumizi ya ofisi.',
    sections: [
      HelpSection('Sehemu', [
        'Maelezo, kiasi (TSh) na ofisi.',
      ]),
    ],
    tips: [
      'Tarehe ni ya siku unayoandika.',
    ],
  ),
  'formBox': HelpTopic(
    title: 'Fomu: Box',
    intro: 'Box jipya au kufunga box.',
    sections: [
      HelpSection('Sehemu', [
        'Aina: Box la ndege au Container ya meli.',
        'Kufunga: uzito wa mwisho (kg) na track number ya box kutoka kampuni ya usafiri.',
      ]),
    ],
    tips: [
      'Box likishafungwa wateja wanapata SMS ya kusafirishwa.',
    ],
  ),
  'formClaim': HelpTopic(
    title: 'Fomu: Dai',
    intro: 'Tatizo la mzigo.',
    sections: [
      HelpSection('Sehemu', [
        'Aina ya tatizo, bidhaa, katoni, maelezo na picha.',
        'Kumaliza: uamuzi, kiasi cha fidia na njia (punguzo/refund).',
      ]),
    ],
    tips: [
      'Picha za wakati wa kupokea China zinasaidia kuthibitisha.',
    ],
  ),
  'formUser': HelpTopic(
    title: 'Fomu: Mtumiaji',
    intro: 'Taarifa za mtumiaji.',
    sections: [
      HelpSection('Sehemu', [
        'Jina, simu (si lazima; Tanzania au +code ya nchi), username, ofisi, jukumu.',
        '"Ofisi zote": zima kumfungia ofisi yake.',
      ]),
    ],
    tips: [
      'Nywila ya muda inaonekana mara moja tu - inakili.',
    ],
  ),
  'formRate': HelpTopic(
    title: 'Fomu: Kiwango / Bei',
    intro: 'Kiwango cha sarafu au bei ya usafirishaji.',
    sections: [
      HelpSection('Sehemu', [
        'Kiwango: thamani ya 1 USD (au sarafu nyingine) kwa TSh.',
        'Bei: uzito/CBM na gharama kwa sarafu uliyochagua.',
      ]),
    ],
    tips: [
      'Kiwango kipya kinatumika kuanzia sasa; malipo ya zamani hayabadiliki.',
    ],
  ),
};

const Map<String, HelpTopic> helpEn = {
  'dashboard': HelpTopic(
    title: 'Dashboard',
    intro: 'The home page shows today\'s business at a glance: where cargo is, payments, debts and pending work.',
    sections: [
      HelpSection('What you see', [
        'Cargo flow: number of invoices at each stage. Tap a stage to open its invoices.',
        'Stat cards: outstanding debt, payments today/this month, storage income this month, overdue cargo in store, expenses, customers, boxes and pending SMS.',
        '7-day income chart and recent invoices.',
        'Pie charts (this month): invoices by status, income (freight / storage), cargo by carrier, payments by method, debt by age.',
      ]),
      HelpSection('Quick actions', [
        '"New invoice" starts an invoice for a customer.',
        'Tap any card (e.g. "Overdue in store") to jump to its page.',
        'The bell 🔔 shows new notifications.',
        'The person-search icon lets you pick a customer and open their dashboard.',
      ]),
    ],
    tips: [
      'Pull down (or tap ⟳) to refresh.',
      'You only see cards for sections you have permission for.',
    ],
  ),
  'customers': HelpTopic(
    title: 'Customers',
    intro: 'All customers. Every invoice belongs to a registered customer.',
    sections: [
      HelpSection('Register a customer', [
        'Tap "New customer".',
        'Enter the full name. The phone number is optional. Tanzanian numbers as 0712 345 678 or +255712345678; other countries with their country code, e.g. +86 138 1234 5678 (China) or +254 712 345 678 (Kenya). One number per customer.',
        'Tap Save.',
      ]),
      HelpSection('Search and filter', [
        'Type a name or number in the search box.',
        'Use filters: All, Active, Blocked.',
      ]),
      HelpSection('Customer actions', [
        'Tap a customer to open details (invoices, debts, history).',
        'Menu ⋮: Edit, Block / Unblock, Delete, New invoice, Call.',
        'A blocked customer cannot get new invoices.',
      ]),
    ],
    tips: [
      'Import many customers from Excel: Settings → Import data.',
      'To message a customer: open the customer → SMS icon.',
    ],
  ),
  'customerDetail': HelpTopic(
    title: 'Customer dashboard',
    intro: 'Everything about one customer and all the business you have done together. Open it from Customers, from the Dashboard (customer search icon) or Reports → Summary → Top customers.',
    sections: [
      HelpSection('Tabs', [
        'Overview: figures (invoices, billed, paid, owing, storage, discount, cartons, kg), pie charts and business by month.',
        'Invoices: every invoice with its cargo (name, cartons, kg, track, price), status, carrier, storage days and amounts.',
        'Payments: every payment and refund - date, receipt, invoice, method, amount, staff.',
        'Handed over: who collected, when and who handed over; the PDF icon opens the note.',
        'Claims and SMS: all claims and messages sent.',
      ]),
      HelpSection('Period and statement', [
        'Shows "All time" by default. Tap the period to choose dates.',
        'PDF icon: customer statement for the period.',
        'Table icon: Excel with invoices, cargo, payments, hand-overs and SMS sheets.',
        'Also: call, message, new invoice, edit/block.',
      ]),
    ],
    tips: [
      'Tap any invoice, payment or hand-over to open the invoice.',
      'Type {jina} in a message - it becomes the customer\'s name.',
    ],
  ),
  'invoices': HelpTopic(
    title: 'Invoices',
    intro: 'An invoice records a customer\'s cargo from China until hand-over. Each has a number (e.g. 0000123).',
    sections: [
      HelpSection('Open a new invoice', [
        'Tap "New invoice" → choose a customer (or register one).',
        'The invoice opens ready for products.',
      ]),
      HelpSection('Search', [
        'Search by invoice number, customer name or phone.',
        '"Find by track": scan or type a product track number.',
        'Filter by status and office.',
      ]),
      HelpSection('Blocked invoices', [
        'Blocked invoices are hidden from daily work.',
        'The Blocked filter has "Delete all blocked" (admins only).',
      ]),
    ],
    tips: [
      'Invoice status changes automatically as cargo moves.',
    ],
  ),
  'invoiceDetail': HelpTopic(
    title: 'Invoice (step by step)',
    intro: 'At the top of an invoice the "Next step" card tells you what to do now:',
    sections: [
      HelpSection('1. Add products (China)', [
        '"Add product": description, cartons, weight, track number, carrier (Air/Sea) and photo.',
        'Price is calculated from shipping prices in Settings.',
        'QR labels: print labels for the cartons.',
      ]),
      HelpSection('2. Register receiver', [
        '"Register receiver": the customer or someone else, and the pickup office.',
        'The invoice moves to Packing.',
      ]),
      HelpSection('3. Box and transit', [
        'In Boxes, pack the products, then "Close and ship".',
        'When the box arrives, receive it in Store.',
      ]),
      HelpSection('4. Bill and payment (Tanzania)', [
        'When cargo is in store tap "Create invoice" (PDF) - the debt opens.',
        'Receive payment: amount, institute and currency. A receipt PDF and SMS are produced.',
        'Discount (with reason) and Refund are available to permitted users.',
      ]),
      HelpSection('5. Hand-over', [
        'When paid tap "Hand over": collector name, phone, ID, signature and photo.',
        'Partial hand-over is possible - the rest stays in store.',
        '"Hand over on credit" (special permission) - refused if the customer\'s credit limit would be exceeded.',
      ]),
      HelpSection('Other actions', [
        'WhatsApp 💬: message + photo, cargo photos, invoice, receipt or hand-over note.',
        'Report a cargo problem → Claims.',
        'Block / reopen, delete (before shipping).',
      ]),
    ],
    tips: [
      'Storage: 7 free days, then \$3 per day - shown in the payment summary.',
      'History shows every step and time.',
    ],
  ),
  'invoiceSms': HelpTopic(
    title: 'Invoice SMS',
    intro: 'The SMS button on an invoice sends a message listing every item on that invoice on its own line.',
    sections: [
      HelpSection('What the message contains', [
        'Cargo status (received in China, in transit, arrived at store, handed over).',
        'Each item: description, cartons, measure (air = kg; sea/container = CBM and tons), carrier and its price.',
        'Totals for cartons, air kg, sea CBM and tons, and price; storage charge, discount, amount paid and balance.',
        'If there is a balance, payment details are added at the end.',
      ]),
      HelpSection('Sending', [
        'Choose the customer, the receiver or both. With WhatsApp permission, choose SMS, WhatsApp or both.',
        'You can edit the text before sending. Use {jina} for the recipient\'s name.',
        'Below the message you see the character count and how many SMS each person will use.',
      ]),
      HelpSection('Automatic SMS', [
        'The "cargo shipped" and "arrived at store" SMS now list every invoice item, not just totals.',
        'If there are more items than SMS_ITEMS_MAX (default 15), the rest are summed on one line.',
      ]),
    ],
    tips: [
      'Long messages cost more SMS: check the count before sending.',
      'Requires SMS (Add) permission.',
    ],
  ),
  'boxes': HelpTopic(
    title: 'Boxes (packing in China)',
    intro: 'A box (air) or container (sea) carries cargo from many invoices to Tanzania.',
    sections: [
      HelpSection('Create a box', [
        'Tap "New box" → Air box or Sea container.',
        'It starts in Packing.',
      ]),
      HelpSection('Pack cargo', [
        'Desktop: drag products from "Waiting" into the box.',
        'Phone: long-press and drag, or open the box → select → add.',
        'You can scan track numbers.',
      ]),
      HelpSection('Ship', [
        'Open the box → "Close and ship" → enter the carrier\'s track number.',
        'Customers get a shipping SMS.',
      ]),
    ],
    tips: [
      'Air boxes take air cargo only; containers take sea cargo only.',
      'An invoice needs a receiver before packing.',
    ],
  ),
  'boxDetail': HelpTopic(
    title: 'Box details',
    intro: 'Inside a box: packed and waiting products, and box actions.',
    sections: [
      HelpSection('Actions', [
        'Add / remove products.',
        'Manifest (PDF).',
        'QR labels for box and cartons.',
        'Box costs (freight, duty, clearing...) - used in the Profit report.',
        'Close and ship; or Receive (in Tanzania).',
      ]),
    ],
    tips: [
      'A closed box cannot take more cargo.',
    ],
  ),
  'store': HelpTopic(
    title: 'Store (receiving boxes)',
    intro: 'Receive boxes that arrived in Tanzania. Receiving a box puts its cargo in store and customers get an SMS.',
    sections: [
      HelpSection('Receive a box', [
        '"Expected" shows boxes in transit.',
        'Tap "Receive" or "Scan to receive".',
        'Check and confirm. Invoices move to Store and storage days start.',
      ]),
      HelpSection('Overdue cargo', [
        'The ⏳ button (with a number) opens cargo stored longer than 7 days.',
        'Every 7 days a popup reminds you.',
      ]),
    ],
    tips: [
      'First 7 days are free; then \$3 per day.',
    ],
  ),
  'overdue': HelpTopic(
    title: 'Overdue cargo in store',
    intro: 'Cargo stored longer than the free days (7). Each extra day costs \$3, converted to TSh at the current USD rate.',
    sections: [
      HelpSection('What you see', [
        'Totals: count, storage charges (TSh and \$) and the oldest cargo.',
        'Per item: customer, invoice, days, chargeable days, charge, balance and last reminder.',
      ]),
      HelpSection('Remind customers', [
        'One: tap 🔔 on the item.',
        'Several: tick items, then "Remind (n)".',
        'All: tap "Remind all".',
        'Choose SMS, WhatsApp or both. Leave the message empty to send the standard text.',
        'Your text may use {jina} {ankara} {siku} {usd} {tsh}.',
      ]),
      HelpSection('7-day popup', [
        'The system checks automatically and shows a popup once every 7 days.',
        'Tap "View cargo" to open this list.',
      ]),
    ],
    tips: [
      'Storage payments appear in Reports → Income ("Storage") and on the Dashboard.',
      'Download Excel with the table icon.',
    ],
  ),
  'delivery': HelpTopic(
    title: 'Hand-over and payments',
    intro: 'Invoices with cargo in store: bill, receive payment and hand cargo to the customer.',
    sections: [
      HelpSection('Daily work', [
        'Find the invoice by name, phone or scan the pickup code from the customer\'s SMS.',
        'If not billed, tap "Bill".',
        '"Pay": amount and method. A receipt is produced.',
        'When paid: "Hand over" → collector details, signature, save. A hand-over note (PDF) is produced.',
      ]),
      HelpSection('Filters', [
        'All, Not billed, Owing, Paid.',
      ]),
      HelpSection('Handed-over cargo ("Handed over" tab)', [
        'Every hand-over, including partial rounds, newest first.',
        'Search by customer, phone, invoice, collector, staff, cargo name or track number.',
        'Filter by period, carrier (Air / Sea), staff member, or credit only.',
        'Tap a row to open the invoice; the PDF icon opens the hand-over note; the table icon downloads Excel.',
      ]),
    ],
    tips: [
      'Storage charges are added automatically after 7 days.',
      'Exchange rates come from Settings.',
    ],
  ),
  'claims': HelpTopic(
    title: 'Claims',
    intro: 'Damaged, lost or short cargo. Open a claim from the invoice ("Report a cargo problem").',
    sections: [
      HelpSection('Open a claim', [
        'Invoice → Actions → "Report a cargo problem".',
        'Choose type, product, cartons, description and photo.',
      ]),
      HelpSection('Resolve', [
        'Open the claim → "Resolve": accept or reject with a resolution; compensation as Discount (on the debt) or Refund.',
      ]),
    ],
    tips: [
      'Filters: Open, Accepted, Rejected.',
    ],
  ),
  'expenses': HelpTopic(
    title: 'Expenses',
    intro: 'Office expenses (rent, fuel, casual labour ...). Used in expenditure and monthly net figures.',
    sections: [
      HelpSection('Record an expense', [
        'Tap "New expense" → details, amount (TSh) and office → Save.',
      ]),
      HelpSection('Edit', [
        'Menu ⋮ → Edit or Delete.',
      ]),
    ],
    tips: [
      'Filter by office and date; the total shows at the top.',
    ],
  ),
  'cashup': HelpTopic(
    title: 'Daily cash-up',
    intro: 'Each evening the accountant compares the payments recorded in the system (per bank / method) with the money actually counted or received. Any difference notifies supervisors.',
    sections: [
      HelpSection('Close the day', [
        'Open Cash-up → "Close day" (today by default; tap the date to change).',
        'For each payment method you see the system amount and number of payments. Enter the amount you counted.',
        'The difference shows immediately (red = short, amber = over, green = matches). Add a note if needed.',
        'Tap "Close day" and confirm. A day can be closed once.',
      ]),
      HelpSection('After closing', [
        'The closed day summary and its PDF are shown.',
        'Payments entered after closing are flagged.',
        'A supervisor (delete payments permission) can reopen a day to close it again.',
        '"History" tab: all closed days, total shortages and overages.',
      ]),
    ],
    tips: [
      'Close every day before leaving the office - it prevents and reveals cash losses early.',
    ],
  ),
  'reports': HelpTopic(
    title: 'Reports',
    intro: 'Business reports for the period you choose - on screen (charts) and as PDF or Excel. Every PDF has figures at the top, pie/bar charts and tables with totals.',
    sections: [
      HelpSection('Tabs', [
        'Summary: period figures, business by month (billed, payments, expenses), pies for carrier, payment methods, expenses by office and top customers.',
        'PDF reports: choose a report, period and filters, then "Generate report".',
        'Income: freight vs storage. Profit: revenue vs box costs. Debt aging. Excel.',
      ]),
      HelpSection('Available PDF reports', [
        'Business summary; Customer statement (choose a customer); Top customers.',
        'Revenue by debt status; Debts (per invoice and per customer, by age).',
        'Cargo received; Boxes and profit; Handed-over cargo - all filterable by carrier (Air/Sea).',
        'Income by payment method (bank, staff, per day); Expenses (by office); Storage income.',
      ]),
      HelpSection('Use', [
        'Pick a period (or This month, 3 months, This year).',
        'Tap the table icon for Excel, or the PDF icon to download/print.',
      ]),
    ],
    tips: [
      'Storage income = the part of payments above the invoice\'s freight amount (up to the storage charge).',
      'Reports are generated by the server directly - Word is not needed.',
    ],
  ),
  'sms': HelpTopic(
    title: 'SMS',
    intro: 'The system sends SMS automatically (received, shipped, arrived, receipts, reminders). Here you see pending, sent and failed messages.',
    sections: [
      HelpSection('New message to customers', [
        'Tap "New message" to message one, selected or all customers.',
      ]),
      HelpSection('Pending', [
        '"Send", "Edit and send", or the send-all icon.',
        'A red ⚠ shows why sending failed.',
      ]),
      HelpSection('Filters', [
        'Kind and Pending / Sent / Not delivered.',
      ]),
      HelpSection('Delivered or not', [
        'Sent messages show "Delivered" (green), "Not delivered" (red, hold for the reason) or "Sent" (accepted by FastHub, no report yet).',
        '"Not delivered" lists every message that did not reach the customer - fix the number or "Resend".',
        'Reports need the delivery-report URL set at FastHub (see the administrator guide).',
      ]),
      HelpSection('SMS balance', [
        'The top of the page shows the SMS balance and this month\'s usage.',
        'When you buy SMS on FastHub, tap "Record purchased SMS". Now and then use "Set actual balance" from the FastHub account to keep the estimate correct.',
        'Below the warning level (default 300) you get a notification and the card turns red.',
      ]),
    ],
    tips: [
      'Turn SMS kinds on/off in Settings → SMS types.',
      'More than 160 characters counts as 2+ SMS.',
    ],
  ),
  'smsBalance': HelpTopic(
    title: 'SMS balance',
    intro: 'The system tracks the FastHub SMS balance so messages never stop unnoticed.',
    sections: [
      HelpSection('Recording', [
        '"Record purchased SMS": the number you just bought - added to the balance.',
        '"Set actual balance": the balance shown in your FastHub account - the estimate starts from it.',
        'Every SMS sent subtracts its parts (long SMS = 2+ parts).',
      ]),
      HelpSection('Warning', [
        'Below SMS_LOW_BALANCE (default 300) users with SMS permission are notified daily until you top up.',
      ]),
    ],
    tips: [
      'If FastHub offers a balance URL, the server administrator can set SMS_BALANCE_API to show the live balance.',
    ],
  ),
  'quotations': HelpTopic(
    title: 'Quotations',
    intro: 'When a customer asks "what will this cost?" before the cargo arrives, create a quotation, send it by SMS or PDF, and convert it to an invoice when accepted.',
    sections: [
      HelpSection('Creating', [
        '"New quotation": pick an existing customer or type a new customer\'s name and phone.',
        'For each item: description, carrier, cartons and measure. Air = kg. Sea (container) = CBM (and kg for tons).',
        'Prices are calculated from the price list in Settings. You can type an amount manually; "Recalculate" returns to the system price.',
        'Choose how long it is valid (7 to 60 days).',
      ]),
      HelpSection('Sending and tracking', [
        'PDF to print or send; SMS/WhatsApp lists every item and the total.',
        'Status: Draft → Sent → Accepted / Rejected → Invoiced. Past the validity date it shows "Expired".',
      ]),
      HelpSection('Converting to an invoice', [
        '"Convert to invoice": a new invoice is created with all items; the customer is registered if new.',
        'When the cargo arrives, adjust weight, track number and photos on the invoice as usual.',
      ]),
    ],
    tips: [
      'A quotation is not a debt - the debt starts when the store invoice is generated.',
      'Permission: Quotations (View, Add, Update, Delete).',
    ],
  ),
  'boxEta': HelpTopic(
    title: 'Expected arrival (ETA)',
    intro: 'Every shipped box has an expected arrival date in Tanzania.',
    sections: [
      HelpSection('How it is set', [
        'When closing a box you can pick an ETA; otherwise the default days apply (air 10, sea 45).',
        'The ETA appears in the "cargo shipped" SMS, on the public tracking page, in Boxes and in Store.',
      ]),
      HelpSection('Late boxes', [
        'If the ETA passes before the box is received it shows "N days late" (red) and store users are notified every morning.',
        'The dashboard shows the number of late boxes.',
        'To change: open the box → ETA card → pick a new date. Turn on "Notify customers" to send an SMS with the new date and reason.',
      ]),
    ],
    tips: [
      'Default days are set on the server: ETA_AIR_DAYS and ETA_SEA_DAYS.',
    ],
  ),
  'forgotPassword': HelpTopic(
    title: 'Forgot password',
    intro: 'On the login screen tap "Forgot password?".',
    sections: [
      HelpSection('Steps', [
        'Type your username or phone number and tap "Send code".',
        'A 6-digit code is sent by SMS to your registered number (it expires after a few minutes).',
        'Enter the code and a new password (at least 8 characters, letters and numbers), then log in.',
      ]),
    ],
    tips: [
      'If the code could not be sent, the reason is shown (e.g. no phone number on the account, or FastHub rejected the SMS).',
      'If your account has no phone number, an administrator must reset your password.',
      'Changing the password logs you out of all other devices.',
    ],
  ),
  'broadcast': HelpTopic(
    title: 'Message customers',
    intro: 'Send your own message by SMS, WhatsApp or both - to one, selected or all customers.',
    sections: [
      HelpSection('1. Choose recipients', [
        'All: every active customer.',
        'Selected: "Choose customers" and tick them.',
        'One: pick a customer or type any phone number: Tanzanian (0712... / +255...) or international with its country code (+86..., +254...), and an optional name.',
        'In store / Overdue in store / Owing: groups filled automatically.',
      ]),
      HelpSection('2. Write', [
        'Write the message. "Insert name" adds {jina} - each customer sees their name.',
        'Use the ready templates and edit.',
        'The counter shows characters and SMS parts (160 = 1 SMS).',
      ]),
      HelpSection('3. Send', [
        'Choose SMS / WhatsApp / Both.',
        '"Preview recipients" shows count, SMS used and a sample.',
        '"Send" → confirm. Turn off "Send now" to keep them pending in SMS.',
      ]),
    ],
    tips: [
      'Custom messages appear in SMS as kind "Custom".',
      'Each number gets one message even with many invoices.',
    ],
  ),
  'users': HelpTopic(
    title: 'Users',
    intro: 'People who use the system. Each user has a role that decides what they can see and do.',
    sections: [
      HelpSection('Add a user', [
        '"New user": name, phone, username, office and role.',
        'A temporary password is shown; the user must change it at first login.',
      ]),
      HelpSection('Actions', [
        'Edit, Block / Unblock, Reset password, Log out everywhere, Delete.',
        'Custom permissions for one person.',
        'Two-factor (2FA): after the password a 6-digit SMS code is required at every login. Recommended for administrators and accountants (needs a valid phone number).',
        '"All offices" off = sees only their office\'s data.',
      ]),
    ],
    tips: [
      'Don\'t share accounts - the audit log records who did what.',
    ],
  ),
  'roles': HelpTopic(
    title: 'Roles',
    intro: 'A role is a set of permissions. Defaults: Administrator, China receiver, Tanzania store, Accountant, Viewer.',
    sections: [
      HelpSection('Use', [
        '"New role" or edit: pick modules and their actions. Each module shows a short description.',
        'Actions that make no sense for a module show as "—" (e.g. Discounts only has "Add").',
        'Tap a module name to switch all its actions on or off.',
        '"Apply to its users" updates everyone with that role.',
      ]),
      HelpSection('What the default roles allow', [
        'Administrator: everything.',
        'China receiver: customers, invoices, cargo, boxes, SMS and WhatsApp. No money.',
        'Tanzania store: store, cargo handover (not on credit), claims, SMS and WhatsApp. No customer money.',
        'Accountant: payments, discounts, refunds, expenses, daily cash-up, reports, profit and dashboard money. Cannot reopen a closed cash-up.',
        'Viewer: read-only, without money, money reports, profit, audit log or backups.',
      ]),
    ],
    tips: [
      'System roles cannot be deleted.',
      'Start with fewer permissions and add when needed.',
    ],
  ),
  'permissions': HelpTopic(
    title: 'Permissions',
    intro: 'One user\'s permissions per module. Each module shows only the actions that make sense for it.',
    sections: [
      HelpSection('Use', [
        'Toggle each action; "Grant all" / "Revoke all".',
        'Changes apply immediately.',
      ]),
      HelpSection('Fine-grained permissions', [
        'Dashboard money: without it the dashboard shows counts only (invoices, boxes, cargo), no amounts.',
        'Finances (reports & customers): without it income, debt, expense and summary reports are hidden, and the customer page hides payments, balance and the statement. Cargo, handover and store reports stay.',
        'Prices & exchange rates: View = pick prices when writing invoices; Add = set a new price or rate. Settings alone is no longer enough.',
        'Cargo handover: Add = hand over paid cargo; Update = hand over on credit.',
        'Discounts, Refunds, Credit limit: each is its own permission, no longer part of Payments.',
        'Claims: Add = report; Update = resolve (compensate or reject).',
        'Daily cash-up: Add = close; Delete = reopen.',
        'Bulk messages: without it a user can only message one customer. Also needed to run debt reminders and to remind everyone with overdue cargo.',
        'WhatsApp, Profit & box costs, Audit log, Backups, Excel import, Quotations: each has its own permission.',
      ]),
    ],
    tips: [
      'For many people with the same job, use Roles.',
      '"Permission denied" means that permission is off for the user.',
    ],
  ),
  'audit': HelpTopic(
    title: 'Audit log',
    intro: 'Every change is recorded: who, what, when and from where.',
    sections: [
      HelpSection('Search', [
        'Search by name, action or data.',
        'Filter by module, date or failures.',
        '"Load more" for older entries.',
      ]),
    ],
    tips: [
      'Entries cannot be edited or deleted by users.',
    ],
  ),
  'settings': HelpTopic(
    title: 'Settings',
    intro: 'Your account, appearance and business settings.',
    sections: [
      HelpSection('Account & appearance', [
        'Change password, language, theme, log out.',
      ]),
      HelpSection('Business', [
        'Exchange rates: TSh rate used for payments and storage charges.',
        'Shipping prices per kg/CBM for air and sea.',
        'Institutes (payment methods), Offices.',
      ]),
      HelpSection('SMS types (on / off)', [
        'Every SMS the system sends has its own switch: received, shipped, arrived, receipts, handover, debt reminders, storage warning, overdue cargo, arrival date (ETA), customer messages, invoice SMS, quotations, login code (2FA), password reset code, system alerts and WhatsApp copies.',
        'A type that is off is never sent. Manual SMS (customer messages, invoice SMS, quotations...) show a message that the type is off.',
        'Turning off "Login code (2FA)" suspends 2FA: users log in with the password only until you turn it back on.',
        'Turning off "Password reset code" means an administrator must reset passwords.',
      ]),
      HelpSection('System', [
        'System health: database, SMS, WhatsApp, backups and scheduled jobs.',
        'Backup: create and download.',
        'Excel import: customers and old debts (download the template first).',
      ]),
    ],
    tips: [
      'Update the USD rate when it changes - storage charges use it.',
    ],
  ),
  'track': HelpTopic(
    title: 'Cargo tracking (for customers)',
    intro: 'Customers can check their cargo without logging in, via the link in their SMS or the "Track cargo" page.',
    sections: [
      HelpSection('Use', [
        'Enter the track number or pickup code → "Track".',
        'Shows stage, free storage days left, storage charge and balance.',
      ]),
    ],
    tips: [
      'Too many attempts are temporarily blocked.',
    ],
  ),
  'changePassword': HelpTopic(
    title: 'Change password',
    intro: 'A new password needs 8+ characters with letters and digits.',
    sections: [
      HelpSection('Steps', [
        'Enter the current (or temporary) password.',
        'Enter the new password twice → Save.',
        'Other devices are logged out.',
      ]),
      HelpSection('Login with an SMS code (2FA)', [
        'If an administrator enabled 2FA for you, a 6-digit SMS code is sent after the password.',
        'Enter the code (valid 5 minutes). Not received? Tap "Resend code" after 45 seconds.',
        '"Remember me": tick to stay logged in; don\'t tick on shared devices.',
      ]),
    ],
    tips: [
      'Forgot it? Ask an administrator to reset it.',
    ],
  ),
  'formProduct': HelpTopic(
    title: 'Form: Product',
    intro: 'Each parcel the customer brought in China.',
    sections: [
      HelpSection('Fields', [
        'Description, cartons, weight (kg) or CBM for sea.',
        'Track number from the courier.',
        'Carrier: Air or Sea.',
        'Photo (helps with claims).',
      ]),
    ],
    tips: [
      'Price is calculated from shipping prices.',
    ],
  ),
  'formPayment': HelpTopic(
    title: 'Form: Receive payment',
    intro: 'Each payment reduces the debt and produces a receipt.',
    sections: [
      HelpSection('Fields', [
        'Amount and currency (converted at the current rate).',
        'Institute (bank / mobile).',
        'Note (optional), e.g. transaction ID.',
      ]),
    ],
    tips: [
      'The amount cannot exceed the balance.',
      'When paid, cargo is ready for hand-over.',
      'Wrong amount? Use Refund - payments are not deleted.',
    ],
  ),
  'formDiscount': HelpTopic(
    title: 'Form: Discount',
    intro: 'A discount reduces the invoice total (including storage).',
    sections: [
      HelpSection('Fields', [
        'Discount amount (TSh).',
        'Reason (required).',
      ]),
    ],
    tips: [
      'Only permitted users can give discounts.',
    ],
  ),
  'formRefund': HelpTopic(
    title: 'Form: Refund',
    intro: 'Return money to the customer.',
    sections: [
      HelpSection('Fields', [
        'Amount (not more than paid).',
        'Method and reason.',
      ]),
    ],
    tips: [
      'Refunds show as negative in payment reports.',
    ],
  ),
  'formHandover': HelpTopic(
    title: 'Form: Hand-over',
    intro: 'Record of who collected the cargo.',
    sections: [
      HelpSection('Fields', [
        'Collector name, phone (optional; Tanzanian or +country code), ID type and number.',
        'Cartons to hand over (partial) - leave all for everything.',
        'Signature and optional photo.',
      ]),
    ],
    tips: [
      'The hand-over note (PDF) can be sent by WhatsApp.',
    ],
  ),
  'formReceiver': HelpTopic(
    title: 'Form: Receiver',
    intro: 'Who collects the cargo in Tanzania, and where.',
    sections: [
      HelpSection('Fields', [
        'The sender or another person (name, phone).',
        'Pickup office.',
      ]),
    ],
    tips: [
      'The invoice then moves to Packing.',
    ],
  ),
  'formCustomer': HelpTopic(
    title: 'Form: Customer',
    intro: 'Customer details.',
    sections: [
      HelpSection('Fields', [
        'Full name.',
        'Phone number (optional): Tanzanian 0712 345 678 / +255712345678, or another country with its code, e.g. +8613812345678. SMS and WhatsApp go here.',
        'Credit limit (TSh, optional): the most owed on cargo released on credit. Empty = system default; 0 = no credit.',
      ]),
    ],
    tips: [
      'One number per customer.',
      'Customers without a number get no SMS.',
    ],
  ),
  'formExpense': HelpTopic(
    title: 'Form: Expense',
    intro: 'Office expense.',
    sections: [
      HelpSection('Fields', [
        'Details, amount (TSh) and office.',
      ]),
    ],
    tips: [
      'Dated today.',
    ],
  ),
  'formBox': HelpTopic(
    title: 'Form: Box',
    intro: 'New box or closing a box.',
    sections: [
      HelpSection('Fields', [
        'Type: Air box or Sea container.',
        'Closing: final weight (kg) and the carrier\'s track number.',
      ]),
    ],
    tips: [
      'Closing sends shipping SMS to customers.',
    ],
  ),
  'formClaim': HelpTopic(
    title: 'Form: Claim',
    intro: 'A cargo problem.',
    sections: [
      HelpSection('Fields', [
        'Problem type, product, cartons, description, photo.',
        'Resolve: decision, amount and method (discount/refund).',
      ]),
    ],
    tips: [
      'Receiving photos help as evidence.',
    ],
  ),
  'formUser': HelpTopic(
    title: 'Form: User',
    intro: 'User details.',
    sections: [
      HelpSection('Fields', [
        'Name, phone (optional; Tanzanian or +country code), username, office, role.',
        '"All offices": turn off to restrict to their office.',
      ]),
    ],
    tips: [
      'The temporary password is shown once - copy it.',
    ],
  ),
  'formRate': HelpTopic(
    title: 'Form: Rate / Price',
    intro: 'Exchange rate or shipping price.',
    sections: [
      HelpSection('Fields', [
        'Rate: value of 1 USD (or other) in TSh.',
        'Price: weight/CBM and cost in the chosen currency.',
      ]),
    ],
    tips: [
      'New rates apply from now; past payments don\'t change.',
    ],
  ),
};

