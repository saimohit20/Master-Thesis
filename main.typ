#import "thesis.typ": *

// =====================================================================
//  Your details. Replace every TODO.
//  Once you have the logo, change  logo: none
//  to                              logo: image("figures/haw-logo.png", width: 7cm)
// =====================================================================
#show: thesis.with(
  title: "Data-Driven Evaluation and Optimization of a Multi-Agent RAG Chatbot with Automated Trust Scoring",
  author: "Sai Mohit",
  reg-number: "TODO",
  program: "Data Science",
  submission-date: "TODO",
  primary-examiner: "TODO",
  secondary-examiner: "TODO",
  external-org: "Bosch Rexroth AG",
  logo: none,
)

// ---------------------------------------------------------------------
//  Front matter, roman page numbers
// ---------------------------------------------------------------------

#declaration()

#front-section("Acknowledgments")[
  TODO. Write this at the very end.
]

#contents()

#front-section("Abstract")[
  TODO. One paragraph. Problem, what was built, how it was evaluated,
  headline result. Write this last.
]

// ---------------------------------------------------------------------
//  Body, page numbers restart at 1
// ---------------------------------------------------------------------
#show: main-matter

#include "chapters/01-introduction.typ"
#include "chapters/02-scope.typ"
#include "chapters/03-literature-review.typ"
#include "chapters/04-theory.typ"
#include "chapters/05-methodology.typ"
#include "chapters/06-experiments-results.typ"
#include "chapters/07-discussion.typ"
#include "chapters/08-conclusion.typ"
#include "chapters/09-future-work.typ"

// ---------------------------------------------------------------------
//  Back matter
// ---------------------------------------------------------------------

#bibliography("refs.bib", title: "Bibliography", style: "ieee")

#list-of-figures()

#list-of-tables()
