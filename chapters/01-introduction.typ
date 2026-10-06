= Introduction

Technology changes faster today than at any point before. An important invention once
took many years to spread and become part of everyday work, but that cycle has grown
much shorter, and artificial intelligence has shortened it further. A skill learned
today can already be outdated by the time it is applied. The World Economic Forum
estimates that around 39% of the skills workers hold today will change or lose their
value between 2025 and 2030 @wef2025.

This shift is visible across industry. Many companies are moving toward Industry 4.0,
where machines are connected, processes run on data, and new digital tools are
introduced continuously. Employees have to keep learning simply to stay current with
the systems they work on. The same pace creates pressure on the companies themselves.
The working environment has become more complex and less predictable, new technologies
disrupt established ways of working, and skilled workers are in short supply
@zornek2024. At the same time many experienced employees are reaching retirement, and
a large part of what they know leaves with them because it was never written down
@pundt2023 @dommermuth2024b. The combined effect is information overload. In large
organisations that operate across many domains, employees face a constant flow of
documentation and training material, and finding the part of it that is both relevant
and trustworthy becomes increasingly difficult @dommermuth2024a.

In response, companies have begun to move from traditional learning toward AI guided
learning. Large language models made this practical, since they can interpret and
produce natural language well enough to answer questions in a conversational way.
Their answers, however, are not always correct. Models produce confident but false
statements, commonly called hallucinations, particularly when the training data is
incomplete, outdated, or does not cover a specific or private domain @fan2024. For
corporate training this is a serious weakness, because employees act on the answers
they receive. Retrieval-Augmented Generation (RAG) was introduced to reduce this risk
by bringing external information into the answering process. A RAG system first
retrieves relevant material from an external source and then uses that material as
context for the generated answer, which keeps the response closer to documented facts
@tural2024.

Bosch Rexroth Academy followed this approach and developed an AI supported learning
assistant called AVAILABLE @dommermuth2025. The system allows employees to learn
directly from the company's own training material. Rather than searching through
documents themselves, users ask a question and receive a short answer together with
references and links to the sources it came from. Each source carries a
trustworthiness rating, so the user can judge how reliable the information is. In this
way the system addresses not only the answer but also the path back to a reliable
source. It works on the Academy's real training material, which exists in several
formats such as presentation slides, PDF documents and instructional videos. The
system offers a question and answer mode, in which the user asks directly and receives
a short answer with linked sources and their trust rating. It also offers a guided
assistant mode, which establishes the user's knowledge level through a few follow-up
questions and then recommends learning content matching that level. A third feature
supports knowledge capture through guided interviews, where an AI driven workflow
helps collect knowledge from experts or retiring employees so that it can be stored
and preserved.The design of this first version is described in the theory chapter, and the changes made to it in this thesis are described in the
methodology.

The first version of the system carried several limitations, some of which the
original work identified as open research questions @dommermuth2025. The most critical
one concerns trust assessment. Source trustworthiness was set manually through fixed
heuristic rules, an approach that does not scale as the corpus grows and cannot
resolve cases where two sources state contradictory information. Retrieval was
restricted to semantic vector search, leaving no complementary mechanism to connect
related content when the wording of the question and the wording of the document
differ. The pipeline offered no observability into how retrieval and generation
behaved at runtime, and no systematic evaluation procedure existed to quantify how
well the system performed.

This thesis extends that baseline into a system referred to as AVAILABLE 2.0 and makes
four contributions.

+ A systematic evaluation of the baseline to locate its performance and reliability
  weaknesses.
+ A hybrid retrieval mechanism that combines vector search with graph based search,
  integrated with the Opik observability tool so that the pipeline becomes
  transparent.
+ An automated trust scoring model that derives document trustworthiness from the
  documents themselves and replaces the manual heuristic.
+ A full evaluation using the RAGAS framework @es2024 to quantify the effect of these
  changes.

The main question this thesis answers is how the AVAILABLE learning assistant can be
improved, through better retrieval and an automated trust model, so that knowledge
transfer in an industrial setting becomes more reliable and more trustworthy. The
question is broken into three parts.

+ What are the main performance and reliability weaknesses of the baseline system, and
  how can they be identified systematically?
+ How can an automated trust scoring model be designed and placed into the pipeline so
  that it judges source reliability and replaces the manual approach?
+ How much do the implemented improvements raise retrieval and answer quality compared
  to the baseline?

The work begins with an exploration of the available data. The training material is
spread across several databases, so an ETL pipeline is built to collect and organise
it, which also makes the rest of the system more modular. The weaknesses of the
current system are then identified, and several modern retrieval approaches are
implemented to address them, together with the automated trust score and the
observability layer. The outcome is a system of higher overall quality that scales
better as the volume of incoming material grows.

The thesis first fixes the boundaries of the work and reviews the published research
on retrieval-augmented generation, graph based retrieval and source reliability, which
positions the contribution against what already exists. It then sets out the
theoretical background needed later, covering language models, the baseline system,
retrieval methods, trust scoring and the metrics used to judge retrieval and
generation quality. The methodology follows and describes the architecture of
AVAILABLE 2.0, the data preparation pipeline, the retrieval implementation, the
automated trust scoring model and the observability layer. The evaluation then
introduces the datasets and the experimental setup before reporting results for
retrieval, generation and trust scoring. The findings are discussed in terms of what
they mean for industrial knowledge transfer and where the approach reaches its limits,
and the thesis closes with the conclusions drawn and the directions that remain open
for future work.
