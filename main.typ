#import "thesis.typ": *

// =====================================================================
//  Your details. Replace every TODO.
//  Once you have the logo, change  logo: none
//  to                              logo: image("figures/haw-logo.png", width: 7cm)
// =====================================================================
#show: thesis.with(
  title: "Data-Driven Evaluation and Optimization of a Multi-Agent RAG Chatbot with Automated Trust Scoring",
  author: "Vanapala Sai Mohit",
  reg-number: "946644",
  program: "Data Science",
  submission-date: "November 03, 2026",
  primary-examiner: "Prof. Dr. Stephan Dorfel",
  secondary-examiner: "Guedria Mohamed Amine",
  external-org: "Bosch Rexroth AG",
  logo: image("figures/HAW_Kiel_Logo.svg", width: 7cm),
)

// ---------------------------------------------------------------------
//  Front matter, roman page numbers
// ---------------------------------------------------------------------

#declaration()

#front-section("Acknowledgments")[
    I would like to thank my supervisor, Guedria Mohamed Amine, for his guidance and
  support throughout this thesis. He gave me the context and background I needed to
  get started, connected me with the right people, and provided the resources to carry
  the project through to completion. His trust in the work and his feedback at every
  stage made the process a smooth one.

  I am grateful to Prof. Dr. Stephan Doerfel for his academic supervision, for the
  opportunity to present my progress regularly, and for the direction he offered at
  each of those discussions.

  My thanks also go to the team at Bosch Rexroth. Their technical background on how
  the company operates shaped the quality of this work, and the brainstorming sessions,
  discussions and reviews along the way were central to how the system took form.

  Finally, I would like to thank the University of Applied Sciences Kiel for the
  opportunity to carry out this thesis, which gave me a close look at how production
  RAG systems are built and where AI genuinely fits into an industrial setting.
]

#contents()

#front-section("Abstract")[
  Manufacturing enterprises accumulate large training and technical knowledge bases
  over years of operation, in which critical information is hard to locate and harder
  to trust. Retrieval-augmented generation (RAG) makes such content conversationally
  accessible, but conventional RAG optimizes relevance alone and offers no signal for
  source reliability. This limitation confines deployments to manually pre-vetted
  corpora and prevents transfer to organically grown ones. This thesis presents
  AVAILABLE 2.0, an industrial knowledge assistant that unifies relevance and
  reliability within a single graph-based mechanism. Hybrid retrieval fuses dense
  vector search with Personalized PageRank over an entity--chunk graph, while an
  automated trust score propagates metadata-derived priors of source, authorship,
  freshness and uniqueness across the same graph, so that both signals arise from one
  propagation operator and are fused at ranking time. The system was evaluated against
  its deployed predecessor on an industrial training corpus spanning more than 300
  courses and a benchmark of 1215 questions. Hybrid retrieval raised correct-source
  identification from 83.2% to 93.6% and context precision from 0.37 to 0.94, with
  gains concentrated on procedural questions, where single-vector retrieval fails
  most. In a knowledge-poisoning experiment, trust-aware ranking increased the
  selection of trustworthy sources from 38% to 71% and reduced answers grounded in
  corrupted sources from 31% to 4%. The results show that automated source-level trust
  scoring is a precondition for extending LLM-based knowledge assistance from curated
  pilot corpora to the grown knowledge bases of production environments.
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
