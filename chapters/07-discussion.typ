= Discussion

This chapter interprets the results of the evaluation, places them next to the existing literature,
states what the evaluation cannot show, and describes what the results mean for the use of the system
at Bosch Rexroth.

== Key Findings

The results answer the three research dimensions in a consistent way. On retrieval, vector search
carried most of the weight. Graph retrieval alone was the weakest of the three legs, with a Hit\@10 of
0.76 and an MRR of 0.48, but joining it with the vector leg raised Hit\@10 from 0.86 to 0.97. The graph
therefore did not replace similarity search. It added recall that similarity search missed, which is
what a retriever needs to do when a later stage can only reorder the chunks it receives and cannot
recover a chunk that was never retrieved. A likely reason for the weak standalone result is that
Personalized PageRank can only start from entities named in the question, so it has little to work with
when a question is worded loosely.

The move from AVAILABLE 1.0 to AVAILABLE 2.0 produced a clear improvement on all three datasets. Hit\@1
rose from 0.39 to 0.66 on Grownfield, from 0.68 to 0.95 on Hydraulics and from 0.56 to 0.68 on the
synthetic set. The largest gains are at the top of the ranking, which matters most in practice, since
the passages at the top of the context are the ones that the generator uses best @liu2024. The gain
was smallest on the synthetic set, where the baseline was already strong. This comparison was run
without the reranker, so the gain comes from the new embedding model, the hybrid search and the union
with the graph leg, and not from reranking. It still measures the redesign as a whole, so it does not
separate the contribution of these three changes.

On generation, the context measures improved much more than the answer measures. Context precision
roughly doubled on Grownfield, from 0.36 to 0.77, because the fused pool of the second version puts
the right passage near the top of the context far more often. Faithfulness moved less, from 0.83 to
0.87, and on the synthetic set it hardly moved at all. A likely reason is that faithfulness depends on
how the model writes from what it is given and not on how the context is ordered. This split is itself
a finding. It shows that better retrieval raises the ceiling for generation quality but does not by
itself change how the model reasons over its evidence. Hydraulics adds a second observation. Retrieval
finds the golden document for every question there, yet generation scores stay the lowest of the three
datasets, so finding the right document is not the only limit on answer quality.

The reranker ablation gives a result that is easy to state. A cross-encoder reranker improved context
precision, from 0.77 to 0.83 with bge-reranker-base and to 0.90 with bge-reranker-v2-m3, but it left
retrieval and answer quality almost unchanged. MRR stayed at 0.73 to 0.74, and the average of
faithfulness and answer relevancy moved from 0.894 to 0.900 and 0.904. The cost was large. The time per
question grew from 13.4 s to 17.8 s and 28.9 s, and with v2-m3 the reranker alone took 15.3 s of the
28.9 s. The same pattern as before appears here. The reranker puts the relevant chunks higher in the
list, but the model reads all of the roughly ten chunks it receives, so a better order inside this
small window does little for the answer. With a window this small, the order of the chunks matters less
than which chunks are in it. For this reason the reranker was switched off in the final system, and
the fusion step now sends the first ten chunks of the fused list to the model directly.

The trust score passed both tests it was built for. Experiment 1 showed that the score reacts to real
damage, that it falls in the right pillar, and that the content drops hold up under a Wilcoxon test
with a correction for multiple comparisons. Experiment 2 showed that the prior, built from content and
metadata, nearly doubled the share of questions in which the genuine document ranked above its
poisoned twin, from 38.4% to 71.1%. It also cut hedged answers, which name both the right and the wrong
value, from 42 to 1 out of 190. The one result that runs against expectation is that the support score
did not add to this effect and by a small margin took away from it. The reason traces back to how the
poisoned twins were built. They are near copies of a trusted document, so they sit in the same part of
the corroboration graph as the original and look just as well supported.

== Comparison with Existing Literature

The pattern that graph retrieval adds recall but cannot stand alone matches what the graph based
retrieval literature argues. GraphRAG @edge2024 and RAPTOR @sarthi2024 both build their case on the same
limitation of pure similarity search, which is that it cannot connect information spread across
documents that share few words. This thesis tests that idea on a mixed domain enterprise corpus with
training material in two languages and finds the same limitation, although here the graph is used as a
complement to vector search and not as a replacement. The choice of Personalized PageRank over a fixed
hop traversal follows the reasoning of HippoRAG @gutierrez2024, that the importance for a specific
question should flow across the whole graph and should not stop after a fixed number of steps. The result
that PageRank recovered more correct documents in the top ten than a single hop supports that reasoning
in a new setting, although the single hop still ranked the correct document first more often.

The fusion of the vector and graph pools by union avoids comparing the scores of the two legs, which
sit on different and incomparable scales. This is the same problem that reciprocal rank fusion
addresses @cormack2009, which is used inside the vector leg. A two stage design, a fast first pass
followed by a precise cross-encoder rerank, is a
common choice in retrieval @nogueira2019, and the reranker did sharpen the order of the chunks here, as
the rise in context precision shows. The finding that this did not carry over to the answers is
specific to the setting of this thesis. The model receives only about ten chunks, and the first stage
already places the golden document among them for most questions. A reranker has more to offer when the
window is narrow or when the first stage is weak, and neither was the case here.

The trust score sits in a less crowded part of the literature. Most work on trustworthiness in RAG
systems @zhou2024 scores the generated answer, or checks
a claim against its source after generation, and does not score the source document before it is
retrieved. The design used here is closer to older work on corroboration, most directly TrustRank from
web spam detection @gyongyi2004, which also blends a document level prior with a corroboration signal
spread across links. That original method was built to catch pages that are structurally different from
their trusted neighbours, such as link farms. The poisoned twins in this thesis are the opposite case.
They are documents built to look like a near copy of a trusted source. That the support score
underperforms here is therefore consistent with a known limitation of corroboration based signals. They
read agreement and not truth, and a well disguised copy earns agreement that it has not earned honestly.

== Limitations

The two expert datasets are small, with 29 questions for Grownfield and 59 for Hydraulics, so a
difference of a single percentage point on them carries more uncertainty than the same difference on the
1215 question synthetic set. The synthetic set gives statistical weight, but its ground truth answers
were generated and not written by a domain expert, which makes its context recall a softer reference.

The comparison of the two system versions measures the redesign as a whole. The embedding model, the
vector store, the graph leg and the fusion all changed at once, so the evaluation shows what the second
version achieves but not how much each change contributed. A study that adds one component at a time
would be needed for that.

The reranker ablation has its own limits. It was run on the 29 Grownfield questions, where one question
is worth about 0.03, so the small differences in Hit\@1, Hit\@3 and answer quality between the three
configurations cannot be told apart from noise. Each configuration was run once, and no repeated runs or
significance tests were made. The times were measured on a CPU, and a GPU would shorten the neural steps
and would reduce the cost of the reranker much more than the cost of the other steps. The conclusion that
the reranker is not worth its time is therefore tied to this hardware and to this question set. It might
look different on a GPU or on questions where the first stage is weaker.

Switching the reranker off also changes what the trust score does. The ranking boost multiplies the
reranker score, so it only acts when the reranker is active. Experiment 2 was run with the reranker
active, with the boost and the trust tag in the prompt both in use. In the final system only the tag in
the prompt remains. The experiment does not separate the effect of the boost from the effect of the tag,
so how much of the gain survives with the tag alone was not measured.

The trust score was built and tested only on the Grownfield corpus, which was chosen because it has rich
metadata and a large set of already approved documents. Whether the same weighting of content and
metadata holds on Hydraulics or Digital Transformation, which differ in language, document type and
authorship pattern, was not tested.

The poisoned twin experiment is a narrow and deliberately hard test. It shows how the trust score
behaves against a near duplicate document with a handful of flipped facts. It does not show how the
score behaves against a document that is simply irrelevant, of low quality or off topic in a more
ordinary way. The result that the support score underperforms here should not be read as the support
score being unhelpful in general. It only shows that it is the wrong tool for this specific and hard
case. The explanation that the twins share the graph neighbourhood of the original was also not tested
separately.

The model based graders need a caution. RAGAS answer correctness agreed with the known correct value on
only 46.0% of the answers, close to chance, while the custom judge reached 86.1%. This concerns answer
correctness on short factual answers. The four RAGAS measures used in the generation comparison were
not checked against a known value in the same way, so their absolute levels should be read with care,
although the compared systems were scored in the same way and the comparison between them is therefore
fair.

No human user study was carried out. All evaluation in this thesis is offline and metric based. It
measures whether the right document was found and whether the written answer matches a known value. It
does not measure whether a learner finds the system more useful, faster or more trustworthy in
practice.

Finally, the content pillar of the trust score is itself scored by a language model that reads a
generated summary. This is a practical and scalable choice, but it means that the score depends on the
judgement of a model, and its accuracy has not been checked against a human rating of the same
documents.

== Practical Implications

For the Bosch Rexroth Academy, the clearest practical outcome is that the correct document now appears
at the top of the results far more often. Hit\@1 rose on all three datasets, and on Hydraulics the golden
document is among the top three results for every question. A learner who reads only the first source
therefore gets the right one in most cases.

The reranker result has a direct operational meaning. Without the reranker, a question takes about 13.4 s
on a CPU instead of 28.9 s with the larger model, while the quality of the answers stays about the same.
For a system that learners use interactively, this is a large gain in responsiveness for almost no loss.
The reranker remains in the code as an option, so the team can switch it on again if the system moves to
a GPU or if later tests show a case where it helps.

Automated trust scoring removes the dependency on manual `trust.json` ratings that most documents never
received under AVAILABLE 1.0. As the corpus keeps growing through self service uploads to SharePoint,
every new document receives a sensible default estimate of its reliability at ingestion, and does not
stay untagged or wait for a person to rate it by hand.

The finding that the prior alone carries the practical benefit, while the support score adds little
against this kind of attack, is directly useful for the team that maintains the system. It suggests that
the lighter document level score can be relied on to guard against near duplicate misinformation
without the heavier corpus level graph being perfectly maintained, which lowers the ongoing
engineering cost of keeping trust scoring useful. The team should keep in mind that with the reranker off
the trust score reaches the model only through the tag in the prompt.

The observability layer built with Opik answers a concrete request of the internal teams. It makes it
possible to trace a wrong answer back to the step that caused it, and to compare a baseline against a
candidate system before the candidate goes into production. This closes the loop between the technical
improvements of this thesis and the operational needs of the team that will maintain the system after
the handover.

Beyond Bosch, the combination used here, fusing vector and graph retrieval and adding a lightweight
document trust layer before retrieval, applies to other enterprise RAG assistants that face the same
conditions. These are multimodal and multilingual source material, a corpus that keeps growing without
central editorial control, and a real cost of answering from an unreliable source.
