import SweetArrowsCore

/// Levels 1–10: the tutorial. Hand-made, and impossible to lose:
/// bounces cost no hearts, and the bag is always big enough for the colors in play
/// (2 colors with 5 slots, 3 colors with 7 slots).
public enum HandmadeLevels {
    struct Source {
        var rows: [String]
        var bag: Int = 5
        /// What the level teaches (shown in the report).
        var lesson: String
    }

    static let sources: [Source] = [
        Source(rows: [
            ".  .  .",
            "^s ^s ^s",
            ".  .  .",
        ], lesson: "Tap a candy: it flies into the jar. Three alike pop."),
        Source(rows: [
            ".  .  .  .",
            ">s >s >s .",
            ".  .  .  .",
        ], lesson: "A candy in the way makes you bounce: start at the front."),
        Source(rows: [
            ".  vm .  .",
            "^s .  >m .",
            "^s .  .  ^s",
            ".  <m .  .",
        ], lesson: "Two colors share the jar."),
        Source(rows: [
            ".  ^l .  .  .",
            "<s ^l >s .  .",
            ".  ^l .  vs .",
            ".  .  <s vs .",
            ".  .  .  .  >s",
        ], lesson: "Look for the candy that is free."),
        Source(rows: [
            ".  .  vm .  .",
            ">b .  vm .  ^b",
            ".  ^m .  ^b .",
            ".  ^m <b >b .",
            ".  .  .  .  .",
            "vm .  >b .  vm",
        ], lesson: "Chains: one candy frees the next."),
        Source(rows: [
            ".  .  .  vl .  .",
            ".  >s >s vl .  .",
            ".  ^s .  .  <l .",
            ".  ^l .  vs <l .",
            ".  .  .  .  .  .",
            ".  >s >l .  vs .",
        ], lesson: "Longer chains across the board."),
        Source(rows: [
            ".  vo .  .  vg .",
            "<o vo .  <g >g .",
            ".  .  ^o .  .  .",
            "<g .  ^o >o .  ^g",
            ".  vo .  .  vo .",
            ".  .  >g .  .  .",
            ".  <o .  .  .  .",
        ], lesson: "A busier counter."),
        Source(rows: [
            "vs .  vl .  vs .",
            "vs >l vl .  >s .",
            ".  .  .  <l .  ^l",
            ">s ^s .  ^l .  ^l",
            ".  vs <l .  vs .",
            "<s .  .  vl .  .",
            ".  .  .  .  .  .",
        ], lesson: "Plan a few moves ahead."),
        Source(rows: [
            ".  vm .  vs .  vl",
            ".  <m .  vl <s vm",
            "^s .  >l .  .  .",
            "^s .  ^m .  ^l <l",
            ".  vm .  >s vm .",
            ".  .  vl .  .  >s",
            ".  .  .  .  .  .",
        ], bag: 7, lesson: "Three colors: keep an eye on the jar."),
        Source(rows: [
            ".  vb .  .  vg .  .",
            "<b vb .  <g >g .  vo",
            ".  .  ^b .  .  .  vo",
            "<g .  ^b >b .  ^g .",
            ".  vb .  .  vb .  <o",
            ".  .  >g .  .  .  .",
            ".  <b .  ^o .  >o .",
            ".  .  .  ^o .  .  .",
        ], bag: 7, lesson: "Graduation: a full board."),
    ]

    public static var count: Int { sources.count }

    public static func lesson(for id: Int) -> String? {
        sources.indices.contains(id - 1) ? sources[id - 1].lesson : nil
    }

    /// The tutorial levels as plain levels (not yet approved by the solver).
    public static func levels() throws -> [Level] {
        try sources.enumerated().map { index, source in
            try AsciiLevel.parse(source.rows, id: index + 1, bagCapacity: source.bag, tutorial: true)
        }
    }
}
