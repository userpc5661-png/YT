import Foundation

enum Catalog {
    static let all: [CatalogTitle] = makeTitles()

    static func title(id: String) -> CatalogTitle? {
        all.first { $0.id == id }
    }

    static func titles(ids: [String]) -> [CatalogTitle] {
        let map = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return ids.compactMap { map[$0] }
    }

    static func featured(kidsOnly: Bool) -> [CatalogTitle] {
        let preferred = titles(ids: ["sintel", "cosmos", "sprite", "wing", "spring", "caminandes", "glass", "hero"])
            .filter { !kidsOnly || $0.kids }
        if !preferred.isEmpty { return preferred }
        return Array(all.filter { !kidsOnly || $0.kids }.prefix(4))
    }

    static func homeLanes(kidsOnly: Bool) -> [Lane] {
        let pool = all.filter { !kidsOnly || $0.kids }
        let ids = Set(pool.map(\.id))
        func keep(_ list: [String]) -> [String] { list.filter { ids.contains($0) } }
        func genre(_ genre: Genre) -> [String] {
            pool.filter { $0.genres.contains(genre) }.map(\.id)
        }
        func stableUnique(_ list: [String]) -> [String] {
            var seen = Set<String>()
            return list.filter { seen.insert($0).inserted }
        }

        var lanes: [Lane] = []
        let trending = keep(["sintel", "bbb", "sprite", "notld", "sherlock", "cosmos", "tos", "friday", "wing", "agent"])
        lanes.append(Lane(id: "trending", title: L10n(ar: "الرائج الآن", en: "Trending now"), titleIDs: trending, style: .poster))

        let top = keep(["sintel", "sherlock", "bbb", "friday", "cosmos", "notld", "nosferatu", "sprite", "johndoe", "wing"])
        lanes.append(Lane(id: "top10", title: L10n(ar: "أفضل ١٠ في ليل", en: "Top 10 on Layl"), titleIDs: top, style: .ranked))

        lanes.append(Lane(
            id: "blender",
            title: L10n(ar: "أفلام بلندر المفتوحة", en: "Blender open movies"),
            titleIDs: keep(["sintel", "bbb", "cosmos", "tos", "spring", "sprite", "ed", "agent", "coffee", "charge", "glass", "hero", "wing", "caminandes"]),
            style: .poster
        ))
        lanes.append(Lane(id: "animation", title: L10n(ar: "رسوم متحركة", en: "Animation"), titleIDs: genre(.animation), style: .poster))
        lanes.append(Lane(id: "family", title: L10n(ar: "مناسب للعائلة", en: "Family"), titleIDs: genre(.family), style: .poster))
        lanes.append(Lane(id: "shorts", title: L10n(ar: "أفلام قصيرة", en: "Shorts"), titleIDs: genre(.shortFilm), style: .poster))
        lanes.append(Lane(id: "classics", title: L10n(ar: "كلاسيكيات المجال العام", en: "Public-domain classics"), titleIDs: genre(.classic), style: .poster))
        lanes.append(Lane(id: "horror", title: L10n(ar: "رعب بعد منتصف الليل", en: "After midnight"), titleIDs: genre(.horror), style: .poster))
        lanes.append(Lane(id: "comedy", title: L10n(ar: "كوميديا", en: "Comedy"), titleIDs: genre(.comedy), style: .poster))
        lanes.append(Lane(id: "scifi", title: L10n(ar: "خيال علمي ومغامرة", en: "Sci-fi and adventure"), titleIDs: stableUnique(genre(.scienceFiction) + genre(.adventure)), style: .poster))
        lanes.append(Lane(id: "drama", title: L10n(ar: "دراما", en: "Drama"), titleIDs: genre(.drama), style: .poster))

        return lanes.filter { $0.titleIDs.count >= 2 }
    }

    static func related(to title: CatalogTitle, kidsOnly: Bool) -> [CatalogTitle] {
        all.filter { other in
            other.id != title.id && (!kidsOnly || other.kids) && !Set(other.genres).isDisjoint(with: Set(title.genres))
        }
        .sorted { lhs, rhs in
            let left = Set(lhs.genres).intersection(title.genres).count
            let right = Set(rhs.genres).intersection(title.genres).count
            if left == right { return lhs.score > rhs.score }
            return left > right
        }
        .prefix(12)
        .map { $0 }
    }

    static func results(query: String, genre: Genre?, kind: TitleKind?, kidsOnly: Bool) -> [CatalogTitle] {
        all.filter { title in
            if kidsOnly && !title.kids { return false }
            if let kind, title.kind != kind { return false }
            if let genre, !title.genres.contains(genre) { return false }
            return title.matches(query.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        .sorted { $0.score > $1.score }
    }
}

private let ccBy3 = "https://creativecommons.org/licenses/by/3.0/"
private let ccBy4 = "https://creativecommons.org/licenses/by/4.0/"
private let ccByND4 = "https://creativecommons.org/licenses/by-nd/4.0/"
private let publicDomain = "https://creativecommons.org/publicdomain/mark/1.0/"

private func makeTitles() -> [CatalogTitle] {
    [
        movie(
            id: "bbb",
            ar: "الأرنب باك الكبير",
            en: "Big Buck Bunny",
            synAr: "أرنب عملاق هادئ يقرر أن يرد الصاع صاعين لثلاثة قوارض أفسدت عليه يومه في المرج. كوميديا قصيرة من مؤسسة بلندر، مرخّصة للمشاركة.",
            synEn: "A gentle giant rabbit decides he has had enough of three rodents ruining his day in the meadow. A Blender Foundation comedy short, free to share.",
            year: 2008, score: 8.4, match: 96,
            maturityAr: "للجميع", maturityEn: "All ages",
            genres: [.animation, .comedy, .family],
            minutes: 10, kids: true,
            creditAr: "ساشا خوديخبوره · مؤسسة بلندر",
            creditEn: "Sacha Goedegebure · Blender Foundation",
            rights: "CC BY 3.0", rightsURL: ccBy3,
            archiveID: "BigBuckBunny_124", file: "Content/big_buck_bunny_720p_surround.mp4",
            quality: .compact
        ),
        movie(
            id: "sintel",
            ar: "سينتل",
            en: "Sintel",
            synAr: "فتاة تسافر عبر الجبال والقرى بحثًا عن تنّينها الصغير سكالز. مغامرة حزينة عن الفقد والوفاء، من أفلام بلندر المفتوحة.",
            synEn: "A young woman crosses mountains and villages searching for Scales, the baby dragon she raised. A Blender open movie about loss and loyalty.",
            year: 2010, score: 8.7, match: 98,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.animation, .fantasy, .adventure, .drama],
            minutes: 15, kids: false,
            creditAr: "كولين ليفي · مؤسسة بلندر",
            creditEn: "Colin Levy · Blender Foundation",
            rights: "CC BY 3.0", rightsURL: ccBy3,
            archiveID: "Sintel", file: "sintel-2048-stereo.mp4",
            quality: .hd
        ),
        movie(
            id: "ed",
            ar: "حلم الفيلة",
            en: "Elephants Dream",
            synAr: "بروغ يقود إيمو في جولة داخل آلة ضخمة لا تخضع لمنطق، بينما يتفكك الاتفاق بينهما. أول فيلم مفتوح من مؤسسة بلندر.",
            synEn: "Proog guides Emo through a vast machine that refuses to make sense, and their partnership starts to crack. The Blender Foundation's first open movie.",
            year: 2006, score: 7.1, match: 84,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.animation, .experimental, .scienceFiction],
            minutes: 11, kids: false,
            creditAr: "بسام كردعلي · مؤسسة بلندر",
            creditEn: "Bassam Kurdali · Blender Foundation",
            rights: "CC BY 3.0", rightsURL: ccBy3,
            archiveID: "ElephantsDream", file: "ed_hd.mp4",
            quality: .compact
        ),
        movie(
            id: "tos",
            ar: "دموع الفولاذ",
            en: "Tears of Steel",
            synAr: "في أمستردام مستقبلية، تحاول مجموعة صغيرة إيقاف آلات خرجت عن السيطرة، وتتشابك القصة مع لقاء قديم لم يُغلق.",
            synEn: "In a future Amsterdam, a small crew tries to stop machines that have slipped their leash, while an old reunion refuses to stay buried.",
            year: 2012, score: 7.9, match: 91,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.scienceFiction, .action, .drama],
            minutes: 12, kids: false,
            creditAr: "إيان هيوبرت · مؤسسة بلندر",
            creditEn: "Ian Hubert · Blender Foundation",
            rights: "CC BY 3.0", rightsURL: ccBy3,
            archiveID: "Tears-of-Steel", file: "tears_of_steel_720p.mp4",
            quality: .compact
        ),
        movie(
            id: "cosmos",
            ar: "مغسلة الكون",
            en: "Cosmos Laundromat",
            synAr: "خروف أنهكه الحظ يلتقي بائعًا غريبًا يعرض عليه حيوات كاملة مقابل دورة في المغسلة. حكاية عن اليأس والبداية من جديد.",
            synEn: "A sheep who has run out of luck meets a strange salesman offering whole new lives, one wash cycle at a time.",
            year: 2015, score: 8.2, match: 94,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.animation, .fantasy, .drama],
            minutes: 12, kids: false,
            creditAr: "استوديو بلندر",
            creditEn: "Blender Studio",
            rights: "CC BY 4.0", rightsURL: ccBy4,
            archiveID: "CosmosLaundromatFirstCycle", file: "Cosmos Laundromat - First Cycle (1080p).mp4",
            quality: .hd
        ),
        movie(
            id: "spring",
            ar: "ربيع",
            en: "Spring",
            synAr: "راعية وكلبها يواجهان أرواح الشتاء كي تستمر دورة الحياة في الجبل. فيلم شعري قصير من أندي غورالتشيك واستوديو بلندر.",
            synEn: "A shepherd girl and her dog face the spirits of winter so the cycle of life on the mountain can continue. A poetic short by Andy Goralczyk and Blender Studio.",
            year: 2019, score: 8.0, match: 93,
            maturityAr: "للجميع", maturityEn: "All ages",
            genres: [.animation, .fantasy, .family, .shortFilm],
            minutes: 8, kids: true,
            creditAr: "أندي غورالتشيك · استوديو بلندر",
            creditEn: "Andy Goralczyk · Blender Studio",
            rights: "CC BY 4.0", rightsURL: ccBy4,
            archiveID: "spring_blenderopenmovie", file: "Spring - Blender Open Movie - YouTube.mp4",
            quality: .hd
        ),
        movie(
            id: "agent",
            ar: "العميل ٣٢٧: عملية الحلاقة",
            en: "Agent 327: Operation Barbershop",
            synAr: "عميل سري يدخل صالون حلاقة يبدو عاديًا، ثم يكتشف أن الكرسي يخبئ أكثر من قصة شعر. مطاردة قصيرة بخفة دم.",
            synEn: "A secret agent walks into an ordinary barbershop and finds the chair is hiding more than a haircut. A short, playful chase.",
            year: 2017, score: 7.4, match: 88,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.animation, .action, .comedy, .shortFilm],
            minutes: 4, kids: false,
            creditAr: "استوديو بلندر",
            creditEn: "Blender Studio",
            rights: "CC BY-ND 4.0", rightsURL: ccByND4,
            archiveID: "agent327operationbarbershop", file: "agent327-1080.mp4",
            quality: .hd
        ),
        movie(
            id: "sprite",
            ar: "رعب التوت",
            en: "Sprite Fright",
            synAr: "مجموعة من الدرّاجين تقتحم غابة معزولة فتقابل كائنات فطر صغيرة، ثم تكتشف أنها ليست لطيفة كما تبدو. كوميديا رعب من بلندر.",
            synEn: "A rowdy group of cyclists rides into an isolated forest and meets small mushroom creatures who are not nearly as gentle as they look.",
            year: 2021, score: 7.6, match: 90,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.animation, .horror, .comedy],
            minutes: 11, kids: false,
            creditAr: "استوديو بلندر",
            creditEn: "Blender Studio",
            rights: "CC BY 4.0", rightsURL: ccBy4,
            archiveID: "sprite-fright", file: "Sprite Fright - Open Movie by Blender Studio-804p.mp4",
            quality: .hd
        ),
        movie(
            id: "coffee",
            ar: "جولة قهوة",
            en: "Coffee Run",
            synAr: "بوقود الكافيين، تجري شابة عبر المدينة وتعبر ذكريات علاقة لم تنتهِ بهدوء. فيلم قصير أنيق من هيالتي هالمارسون.",
            synEn: "Fueled by caffeine, a young woman runs through the city and through the bittersweet memories of a relationship. A short by Hjalti Hjalmarsson.",
            year: 2020, score: 7.3, match: 86,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.animation, .drama, .romance, .shortFilm],
            minutes: 3, kids: false,
            creditAr: "هيالتي هالمارسون · استوديو بلندر",
            creditEn: "Hjalti Hjalmarsson · Blender Studio",
            rights: "CC BY-ND 4.0", rightsURL: ccByND4,
            archiveID: "coffee-run", file: "Coffee Run.ia.mp4",
            quality: .hd
        ),
        movie(
            id: "charge",
            ar: "شحنة",
            en: "Charge",
            synAr: "في مدينة تشحّ فيها الطاقة، يقتحم رجل مسنّ مصنع بطاريات فيجد نفسه محاصرًا مع روبوت حراسة لا يرحم.",
            synEn: "In a city starving for power, a destitute old man breaks into a battery factory and is trapped with a deadly security droid.",
            year: 2022, score: 7.5, match: 89,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.animation, .scienceFiction, .action, .shortFilm],
            minutes: 4, kids: false,
            creditAr: "استوديو بلندر",
            creditEn: "Blender Studio",
            rights: "CC BY 4.0", rightsURL: ccBy4,
            archiveID: "charge-blender-open-movie-1608p", file: "Charge - Blender Open Movie 1608p.mp4",
            quality: .hd
        ),
        movie(
            id: "glass",
            ar: "نصف الكأس",
            en: "Glass Half",
            synAr: "ناقدان هاويان يتجادلان في معرض حتى يعمّ الفوضى، ثم يجدان أخيرًا لوحة يتفقان عليها. كوميديا رسم قصيرة من بيورن ليونارد.",
            synEn: "Two amateur critics argue their way through a gallery, causing chaos, until they finally find one piece they both like. A cartoon short by Beorn Leonard.",
            year: 2015, score: 7.2, match: 85,
            maturityAr: "للجميع", maturityEn: "All ages",
            genres: [.animation, .comedy, .family, .shortFilm],
            minutes: 3, kids: true,
            creditAr: "بيورن ليونارد · معهد بلندر",
            creditEn: "Beorn Leonard · Blender Institute",
            rights: "CC BY 4.0", rightsURL: ccBy4,
            archiveID: "GlassHalf1080p", file: "Glass Half-1080p.mp4",
            quality: .hd
        ),
        movie(
            id: "hero",
            ar: "البطل",
            en: "Hero",
            synAr: "فيلم بلندر المرسوم يدويًا بتقنية غريس بنسل: مواجهة قصيرة أمام نصب كبير، وشخصيات تحاول أن تثبت من يستحق أن يُدعى بطلًا.",
            synEn: "Blender's hand-drawn Grease Pencil short: a brief standoff in front of a monument, and a cast arguing, in pictures, who gets to be called a hero.",
            year: 2018, score: 7.0, match: 82,
            maturityAr: "للجميع", maturityEn: "All ages",
            genres: [.animation, .adventure, .shortFilm, .family],
            minutes: 4, kids: true,
            creditAr: "دانيال مارتينيز لارا · استوديو بلندر",
            creditEn: "Daniel Martinez Lara · Blender Studio",
            rights: "CC BY 4.0", rightsURL: ccBy4,
            archiveID: "hero_20260106", file: "hero.ia.mp4",
            quality: .hd
        ),
        movie(
            id: "wing",
            ar: "حلّق",
            en: "Wing It!",
            synAr: "مهندس دقيق المزاج يستقبل زائرًا متحمسًا يظن نفسه طيارًا، فيجد الاثنان نفسيهما داخل مركبة خرجت عن السيطرة.",
            synEn: "An uptight engineer gets a visit from an enthusiastic would-be pilot, and both are launched aboard a shuttle that will not sit still.",
            year: 2023, score: 7.4, match: 90,
            maturityAr: "للجميع", maturityEn: "All ages",
            genres: [.animation, .comedy, .adventure, .family, .shortFilm],
            minutes: 4, kids: true,
            creditAr: "استوديو بلندر",
            creditEn: "Blender Studio",
            rights: "CC BY 4.0", rightsURL: ccBy4,
            archiveID: "wing_it", file: "wing_it.ia.mp4",
            quality: .hd
        ),
        caminandes(),
        movie(
            id: "notld",
            ar: "ليلة الموتى الأحياء",
            en: "Night of the Living Dead",
            synAr: "سبعة غرباء يتحصّنون في بيت ريفي بينما يقوم الموتى ويطرقون النوافذ. فيلم جورج روميرو الذي أعاد تشكيل الرعب، وهو في الملك العام.",
            synEn: "Seven strangers barricade a farmhouse while the dead rise and test the windows. George Romero's film reset horror, and it is in the public domain.",
            year: 1968, score: 7.8, match: 92,
            maturityAr: "١٦+", maturityEn: "16+",
            genres: [.horror, .classic, .thriller],
            minutes: 96, kids: false,
            creditAr: "جورج روميرو",
            creditEn: "George A. Romero",
            cast: [L10n(ar: "دوان جونز", en: "Duane Jones"), L10n(ar: "جوديث أوديا", en: "Judith O'Dea")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "Night.Of.The.Living.Dead_1080p", file: "NightOfTheLivingDead_DVD5_512kb.mp4",
            quality: .archival
        ),
        movie(
            id: "nosferatu",
            ar: "نوسفيراتو",
            en: "Nosferatu",
            synAr: "كونت شاحب يعبر البحر إلى مدينة هادئة، ويحمل معه ظلًا لا ينام. السيمفونية الصامتة لفريدريش مورناو من عام ١٩٢٢، في الملك العام.",
            synEn: "A pale count crosses the sea into a quiet city and brings a shadow that does not sleep. F. W. Murnau's 1922 silent symphony, in the public domain.",
            year: 1922, score: 8.0, match: 93,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.horror, .classic, .fantasy],
            minutes: 92, kids: false,
            creditAr: "فريدريش فيلهلم مورناو",
            creditEn: "F. W. Murnau",
            cast: [L10n(ar: "ماكس شريك", en: "Max Schreck"), L10n(ar: "غريت شرودر", en: "Greta Schröder")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "Nosferatu1922", file: "Nosferatu-smaller2.mp4",
            quality: .archival
        ),
        movie(
            id: "sherlock",
            ar: "شارلوك الصغير",
            en: "Sherlock Jr.",
            synAr: "عارض أفلام يحلم بأنه محقق، ثم يدخل حرفيًا إلى الشاشة. واحدة من أرقى كوميديات باستر كيتون الصامتة.",
            synEn: "A projectionist dreams he is a detective, then walks straight into the movie on screen. One of Buster Keaton's sharpest silent comedies.",
            year: 1924, score: 8.6, match: 97,
            maturityAr: "للجميع", maturityEn: "All ages",
            genres: [.comedy, .classic, .family],
            minutes: 45, kids: true,
            creditAr: "باستر كيتون",
            creditEn: "Buster Keaton",
            cast: [L10n(ar: "باستر كيتون", en: "Buster Keaton")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "sherlockjr1924_201909", file: "Sherlock Jr. - Buster Keaton (1924) HD [720p].mp4",
            quality: .hd
        ),
        movie(
            id: "steamboat",
            ar: "ستيمبوت بيل الابن",
            en: "Steamboat Bill, Jr.",
            synAr: "طالب أنيق يعود إلى والده القاسي قبطان الباخرة، فيصطدم إعصار بالمدينة. كيتون في واحدة من أشهر لقطات السينما الصامتة.",
            synEn: "A dandy son comes home to his hard-nosed riverboat father just as a cyclone hits town. Keaton, and one of silent cinema's most famous shots.",
            year: 1928, score: 8.3, match: 95,
            maturityAr: "للجميع", maturityEn: "All ages",
            genres: [.comedy, .classic, .family],
            minutes: 69, kids: true,
            creditAr: "تشارلز رايزنر · باستر كيتون",
            creditEn: "Charles Reisner · Buster Keaton",
            cast: [L10n(ar: "باستر كيتون", en: "Buster Keaton")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "steamboat_bill_ipod", file: "steamboat_bill_512kb.mp4",
            quality: .archival
        ),
        movie(
            id: "plan9",
            ar: "الخطة ٩ من الفضاء الخارجي",
            en: "Plan 9 from Outer Space",
            synAr: "غرباء من الفضاء يحاولون إيقاف البشر بإحياء الموتى. فيلم إد وود الشهير بسوء سمعته، وهو متاح في الملك العام.",
            synEn: "Aliens try to stop humanity by raising the dead. Ed Wood's famously ramshackle science-fiction film, available in the public domain.",
            year: 1959, score: 6.2, match: 74,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.scienceFiction, .horror, .classic],
            minutes: 78, kids: false,
            creditAr: "إد وود",
            creditEn: "Ed Wood",
            cast: [L10n(ar: "بيلا لوغوسي", en: "Bela Lugosi"), L10n(ar: "ميلدريد جونسون", en: "Vampira")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "plan-9-from-outer-space", file: "plan-9-from-outer-space.mp4",
            quality: .archival
        ),
        movie(
            id: "friday",
            ar: "فتاته يوم الجمعة",
            en: "His Girl Friday",
            synAr: "محررة لامعة تحاول ترك الصحافة والزواج، فيجرّها رئيس تحريرها السابق إلى خبر لا يمكن مقاومته. حوار سريع من هوارد هوكس.",
            synEn: "A star reporter tries to leave the paper and get married, until her ex-editor drags her into a story she cannot walk away from. Howard Hawks, at full speed.",
            year: 1940, score: 8.5, match: 96,
            maturityAr: "للجميع", maturityEn: "All ages",
            genres: [.comedy, .classic, .romance, .drama],
            minutes: 92, kids: false,
            creditAr: "هوارد هوكس",
            creditEn: "Howard Hawks",
            cast: [L10n(ar: "كاري غرانت", en: "Cary Grant"), L10n(ar: "روزاليند راسل", en: "Rosalind Russell")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "his_girl_friday", file: "his_girl_friday_512kb.mp4",
            quality: .archival
        ),
        movie(
            id: "carnival",
            ar: "كرنفال الأرواح",
            en: "Carnival of Souls",
            synAr: "بعد حادث على جسر، تنتقل عازفة أورغن إلى مدينة جديدة وتجد نفسها منجذبة إلى جناح مهجور على البحيرة. فيلم مستقل هادئ ومقلق.",
            synEn: "After a bridge accident, an organist moves to a new city and is pulled toward an abandoned pavilion on the lake. A quiet, unsettling independent film.",
            year: 1962, score: 7.4, match: 87,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.horror, .classic, .thriller],
            minutes: 82, kids: false,
            creditAr: "هيريك هارفي",
            creditEn: "Herk Harvey",
            cast: [L10n(ar: "كانديس هيليغوس", en: "Candace Hilligoss")],
            rights: "CC BY 3.0", rightsURL: ccBy3,
            archiveID: "CarnivalOfSouls1962", file: "Carnival_of_Souls.mp4",
            quality: .archival
        ),
        movie(
            id: "detour",
            ar: "انعطاف",
            en: "Detour",
            synAr: "عازف بيانو يقطع أمريكا توصيلةً بعد توصيلة، ثم يجد أن كل منعطف يضيّق عليه الخناق. نوآر صغير حاد من إدغار أولمر.",
            synEn: "A piano player hitchhikes across America and finds every turn of the road closing in. A lean, bitter noir from Edgar G. Ulmer.",
            year: 1945, score: 7.7, match: 90,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.thriller, .crime, .classic, .drama],
            minutes: 68, kids: false,
            creditAr: "إدغار جي. أولمر",
            creditEn: "Edgar G. Ulmer",
            cast: [L10n(ar: "توم نيل", en: "Tom Neal"), L10n(ar: "آن سافيدج", en: "Ann Savage")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "Detour1945_201808", file: "Detour (1945).mp4",
            quality: .archival
        ),
        movie(
            id: "hill",
            ar: "البيت على التل المسكون",
            en: "House on Haunted Hill",
            synAr: "مليونير يعرض عشرة آلاف دولار لمن يصمد ليلة في بيت يقال إنه مسكون. دعوة ويليام كاسل الكلاسيكية، بضيافة فينسنت برايس.",
            synEn: "A millionaire offers ten thousand dollars to anyone who lasts the night in a house that is supposed to be haunted. William Castle's invitation, hosted by Vincent Price.",
            year: 1959, score: 6.8, match: 81,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.horror, .classic, .thriller],
            minutes: 75, kids: false,
            creditAr: "ويليام كاسل",
            creditEn: "William Castle",
            cast: [L10n(ar: "فينسنت برايس", en: "Vincent Price")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "house_on_haunted_hill_ipod", file: "house_on_haunted_hill_512kb.mp4",
            quality: .archival
        ),
        movie(
            id: "teens",
            ar: "مراهقون من الفضاء الخارجي",
            en: "Teenagers from Outer Space",
            synAr: "يصل زائر من كوكب آخر إلى ضاحية أمريكية، ومعه سلاح وسرّ عن الغزو. خيال علمي متواضع الميزانية من أواخر الخمسينات، في الملك العام.",
            synEn: "A visitor from another world lands in an American suburb with a weapon and a secret about an invasion. A late-1950s public-domain science-fiction quickie.",
            year: 1959, score: 5.8, match: 70,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.scienceFiction, .classic],
            minutes: 86, kids: false,
            creditAr: "توم غريف",
            creditEn: "Tom Graeff",
            cast: [L10n(ar: "ديفيد لوف", en: "David Love"), L10n(ar: "داون بندر", en: "Dawn Bender")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "teenagers_from_outerspace", file: "Teenagers_from_Outer_Space_512kb.mp4",
            quality: .archival
        ),
        movie(
            id: "johndoe",
            ar: "قابلوا جون دو",
            en: "Meet John Doe",
            synAr: "صحفية تخترع رسالة من رجل هدد بالقفز احتجاجًا على حال البلد، ثم تبحث عن شخص يجسّد القصة. دراما فرانك كابرا عن الشهرة والصدق.",
            synEn: "A columnist invents a letter from a man who says he will jump in protest, then has to find someone to be him. Frank Capra on fame, crowds, and honesty.",
            year: 1941, score: 7.9, match: 91,
            maturityAr: "للجميع", maturityEn: "All ages",
            genres: [.drama, .classic, .romance],
            minutes: 123, kids: false,
            creditAr: "فرانك كابرا",
            creditEn: "Frank Capra",
            cast: [L10n(ar: "غاري كوبر", en: "Gary Cooper"), L10n(ar: "باربرا ستانويك", en: "Barbara Stanwyck")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "meet_john_doe", file: "meet_john_doe_512kb.mp4",
            quality: .archival
        ),
        movie(
            id: "shop",
            ar: "دكان الرعب الصغير",
            en: "The Little Shop of Horrors",
            synAr: "بائع في محل زهور يربّي نبتة لا تنمو إلا إذا أُطعمت شيئًا لا يُذكر في وضح النهار. الكوميديا السوداء الأصلية لروجر كورمان، قبل المسرحية الموسيقية.",
            synEn: "A flower-shop clerk raises a plant that will only grow if it is fed something best not said out loud. Roger Corman's original black comedy, long before the musical.",
            year: 1960, score: 6.9, match: 83,
            maturityAr: "١٣+", maturityEn: "13+",
            genres: [.comedy, .horror, .classic],
            minutes: 73, kids: false,
            creditAr: "روجر كورمان",
            creditEn: "Roger Corman",
            cast: [L10n(ar: "جوناثان هيز", en: "Jonathan Haze"), L10n(ar: "جاكي جوزيف", en: "Jackie Joseph")],
            rights: "Public Domain", rightsURL: publicDomain,
            archiveID: "TheLittleShopOfHorrors1960", file: "The-Little-Shop-of-Horrors_512kb.mp4",
            quality: .archival
        )
    ]
}

private func movie(
    id: String,
    ar: String,
    en: String,
    synAr: String,
    synEn: String,
    year: Int,
    score: Double,
    match: Int,
    maturityAr: String,
    maturityEn: String,
    genres: [Genre],
    minutes: Int,
    kids: Bool,
    creditAr: String,
    creditEn: String,
    cast: [L10n] = [],
    rights: String,
    rightsURL: String,
    archiveID: String,
    file: String,
    quality: TransferQuality
) -> CatalogTitle {
    let title = L10n(ar: ar, en: en)
    let synopsis = L10n(ar: synAr, en: synEn)
    let episode = Episode(
        id: "\(id)-main",
        season: 1,
        number: 1,
        title: title,
        synopsis: synopsis,
        minutes: minutes,
        videoURL: MediaURL.archive(identifier: archiveID, file: file),
        stillAsset: "backdrop_\(id)"
    )
    return CatalogTitle(
        id: id,
        title: title,
        synopsis: synopsis,
        year: year,
        score: score,
        match: match,
        maturity: L10n(ar: maturityAr, en: maturityEn),
        genres: genres,
        kind: .movie,
        minutes: minutes,
        kids: kids,
        posterAsset: "poster_\(id)",
        backdropAsset: "backdrop_\(id)",
        credit: L10n(ar: creditAr, en: creditEn),
        cast: cast,
        rights: rights,
        rightsURL: rightsURL,
        archiveID: archiveID,
        quality: quality,
        episodes: [episode]
    )
}

private func caminandes() -> CatalogTitle {
    let episodes: [Episode] = [
        Episode(
            id: "cam1",
            season: 1,
            number: 1,
            title: L10n(ar: "دراما اللاما", en: "Llama Drama"),
            synopsis: L10n(
                ar: "كورو اللاما يحاول عبور جسر عنيد ليصل إلى العشب في الجهة الأخرى.",
                en: "Koro the llama tries to cross a stubborn bridge for the grass on the other side."
            ),
            minutes: 2,
            videoURL: MediaURL.archive(identifier: "Caminandes1LlamaDrama", file: "01_llama_drama_1080p.mp4"),
            stillAsset: "backdrop_cam1"
        ),
        Episode(
            id: "cam2",
            season: 1,
            number: 2,
            title: L10n(ar: "غران ديلاما", en: "Gran Dillama"),
            synopsis: L10n(
                ar: "كورو يطارد ثمرة لا تريد أن تُؤكل بسهولة في سهول باتاغونيا.",
                en: "Koro chases a treat across Patagonia that refuses to be eaten quietly."
            ),
            minutes: 2,
            videoURL: MediaURL.archive(identifier: "Caminandes2GranDillama", file: "02_gran_dillama_1080p.mp4"),
            stillAsset: "backdrop_cam2"
        ),
        Episode(
            id: "cam3",
            season: 1,
            number: 3,
            title: L10n(ar: "لاميغوس", en: "Llamigos"),
            synopsis: L10n(
                ar: "صداقة غير متوقعة تجمع كورو ببطريق وسط الريح.",
                en: "An unexpected friendship starts between Koro and a penguin in the wind."
            ),
            minutes: 3,
            videoURL: MediaURL.archive(identifier: "CaminandesLlamigos", file: "Caminandes_ Llamigos-1080p.mp4"),
            stillAsset: "backdrop_cam3"
        )
    ]
    return CatalogTitle(
        id: "caminandes",
        title: L10n(ar: "كامينانديس", en: "Caminandes"),
        synopsis: L10n(
            ar: "مغامرات كورو، لاما باتاغونيا، في ثلاث حلقات قصيرة: جسر، ثمرة، وصديق جديد. سلسلة مفتوحة من بلندر.",
            en: "Koro, a Patagonian llama, in three short adventures: a bridge, a treat, and a new friend. An open series from Blender."
        ),
        year: 2016,
        score: 8.1,
        match: 95,
        maturity: L10n(ar: "للجميع", en: "All ages"),
        genres: [.animation, .comedy, .family, .adventure, .shortFilm],
        kind: .series,
        minutes: 7,
        kids: true,
        posterAsset: "poster_caminandes",
        backdropAsset: "backdrop_caminandes",
        credit: L10n(ar: "استوديو بلندر", en: "Blender Studio"),
        cast: [],
        rights: "CC BY 3.0",
        rightsURL: ccBy3,
        archiveID: "CaminandesLlamigos",
        quality: .hd,
        episodes: episodes
    )
}
