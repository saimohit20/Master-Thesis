// =====================================================================
//  HAW Kiel master thesis template for Typst
//  All styling lives in this file. You should rarely need to touch it.
// =====================================================================

#let info = state("info", (:))

#let thesis(
  title: "Thesis title",
  author: "Author Name",
  reg-number: "000000",
  program: "Data Science",
  submission-date: "Month DD, YYYY",
  primary-examiner: "Prof. Dr. Name",
  secondary-examiner: "Dr. Name",
  external-org: "Company Name",
  faculty: "Faculty of Media",
  university: "Kiel University of Applied Sciences",
  logo: none,
  body,
) = {
  info.update((
    title: title,
    author: author,
    reg-number: reg-number,
    program: program,
  ))

  // ---------- text ----------
  set text(font: "New Computer Modern", size: 12pt, lang: "en")
  set par(justify: true, leading: 1em, spacing: 1.4em)

  // ---------- page ----------
  set page(
    paper: "a4",
    margin: (left: 3cm, right: 1.9cm, top: 2.5cm, bottom: 2.5cm),
    header: context {
      let this-page = here().page()
      let chapters = query(heading.where(level: 1)).filter(h => h.numbering != none)
      let current = none
      for ch in chapters {
        if ch.location().page() <= this-page { current = ch }
      }
      if current != none and current.location().page() != this-page {
        let n = counter(heading).at(current.location()).first()
        set text(size: 10pt)
        block(width: 100%, below: 0pt)[
          Chapter #n: #current.body
          #v(3pt)
          #line(length: 100%, stroke: 0.5pt)
        ]
      }
    },
  )

  // ---------- headings ----------
  set heading(numbering: "1.1")

  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    counter(figure.where(kind: image)).update(0)
    counter(figure.where(kind: table)).update(0)
    counter(math.equation).update(0)
    v(1cm)
    block(below: 1.2em)[
      #set text(size: 22pt, weight: "bold")
      #if it.numbering != none [
        #counter(heading).display() #h(0.7cm)
      ]
      #it.body
    ]
  }

  show heading.where(level: 2): set text(size: 15pt)
  show heading.where(level: 3): set text(size: 13pt)
  show heading: set block(above: 1.6em, below: 1em)

  // ---------- figures, tables, equations ----------
  set figure(numbering: n => numbering("1.1", counter(heading).get().first(), n))
  set math.equation(numbering: n => numbering("(1.1)", counter(heading).get().first(), n))
  show figure.where(kind: table): set figure.caption(position: top)
  set figure(gap: 1em)

  // ---------- title page ----------
  page(header: none, numbering: none)[
    #set align(center)
    #v(1cm)
    #if logo != none { logo } else {
      rect(width: 7cm, height: 2.2cm, stroke: 0.5pt + gray)[
        #set align(center + horizon)
        #text(size: 10pt, fill: gray)[HAW Kiel logo goes here]
      ]
    }
    #v(2.5cm)
    #university \
    #faculty \
    #text(weight: "bold")[Master Thesis]
    #v(1.5cm)
    #block(width: 85%)[
      #text(size: 20pt, weight: "bold")[#title]
    ]
    #v(2.5cm)
    #set align(left)
    #block(width: 100%)[
      #grid(
        columns: (6cm, 1fr),
        row-gutter: 0.7em,
        text(weight: "bold")[Submitted by:], author,
        text(weight: "bold")[Registration number:], reg-number,
        text(weight: "bold")[Degree Program:], program,
        text(weight: "bold")[Submission Date:], submission-date,
        text(weight: "bold")[Primary Examiner:], primary-examiner,
        text(weight: "bold")[Secondary Examiner:], secondary-examiner,
        text(weight: "bold")[External organization:], external-org,
      )
    ]
  ]

  set page(numbering: "i")
  counter(page).update(1)

  body
}

// ---------------------------------------------------------------------
//  Front matter helpers
// ---------------------------------------------------------------------

#let declaration() = context {
  let d = info.get()
  heading(level: 1, numbering: none, outlined: false)[Declaration]

  set text(size: 9pt)
  [
    NBl. HS MSGWG Schl.-H. Nr. 6/2016 vom 20. Dezember 2016, S. 102 \
    Tag der Bekanntmachung auf der Internetseite der Fachhochschule Kiel: 20. Oktober 2016 \
    37 Anlage D (zu § 28 PVO)
  ]
  v(1em)

  set text(size: 11pt)
  [
    Name: #d.author \
    Martikel-Nr.: #d.reg-number \
    Studiengang: #d.program
  ]
  v(1em)

  [
    Ich versichere, dass ich die Masterarbeit "#d.title" selbständig und ohne
    unzulässige fremde Hilfe angefertigt habe und dass ich alle von anderen Autoren
    wörtlich übernommenen Stellen wie auch die sich an die Gedankengänge anderer
    Autoren eng anlehnenden Ausführungen meiner Arbeit besonders gekennzeichnet und
    die entsprechenden Quellen angegeben habe. Diese Arbeit hat noch keiner
    Prüfungsbehörde vorgelegen.
  ]
  v(1.5em)
  grid(columns: (1fr, 1fr), [Ort, Datum:], [Unterschrift:])
  v(2em)

  [
    I certify that I have completed the Master's thesis "#d.title" independently and
    without unauthorized outside help and that I have specifically marked all passages
    taken verbatim from other authors as well as those closely based on the ideas of
    other authors in my work and have cited the corresponding sources. This thesis has
    not yet been submitted to any examination authority.
  ]
  v(1.5em)
  grid(columns: (1fr, 1fr), [Place, Date:], [Signature:])
}

#let front-section(title, body) = {
  heading(level: 1, numbering: none, outlined: false)[#title]
  body
}

#let contents() = {
  heading(level: 1, numbering: none, outlined: false)[Contents]
  outline(title: none, depth: 3, indent: auto)
}

// ---------------------------------------------------------------------
//  Switches to arabic page numbers starting at 1
// ---------------------------------------------------------------------
#let main-matter(body) = {
  set page(numbering: "1")
  pagebreak(weak: true)
  counter(page).update(1)
  body
}

// ---------------------------------------------------------------------
//  Lists of figures and tables
// ---------------------------------------------------------------------
#let list-of-figures() = {
  heading(level: 1, numbering: none, outlined: true)[List of Figures]
  outline(title: none, target: figure.where(kind: image))
}

#let list-of-tables() = {
  heading(level: 1, numbering: none, outlined: true)[List of Tables]
  outline(title: none, target: figure.where(kind: table))
}

// ---------------------------------------------------------------------
//  Thesis style table with horizontal rules only
// ---------------------------------------------------------------------
#let thesis-table(columns: auto, align: auto, header: (), ..cells) = {
  set text(size: 10pt)
  set par(justify: false)
  table(
    columns: columns,
    align: align,
    stroke: none,
    inset: (x: 7pt, y: 5pt),
    table.hline(stroke: 1pt),
    table.header(..header.map(h => strong(h))),
    table.hline(stroke: 0.5pt),
    ..cells,
    table.hline(stroke: 1pt),
  )
}