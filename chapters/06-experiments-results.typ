#import "../thesis.typ": thesis-table

= Experiments and Results

This chapter presents the results of the evaluation designed in the methodology. The results
are reported in the order in which the methodology introduced the components. Retrieval comes
first. It covers the choice of the graph traversal engine, the comparison of vector, graph and
hybrid retrieval, and the change from AVAILABLE 1.0 to AVAILABLE 2.0. Generation follows, judged
with reference-based and reference-free measures, namely faithfulness, context precision, answer
relevancy and context recall. The trust score closes the chapter through two experiments, one
that checks whether the score detects deliberate quality loss, and one that checks whether it
helps the system resist poisoned material.

== Experimental Datasets

The evaluation uses three datasets that differ in origin, language and difficulty, as described
in the methodology. The Grownfield set holds 33 questions written by the expert team on the SAP
training, 17 of them single-hop and 16 multi-hop, which makes it the test for reasoning across
several documents. The Hydraulics set holds 59 expert questions in German, all drawn from one
training handbook, which makes it a narrow and well covered topic. The synthetic set holds 1215
questions built across all three subject areas, five per source document and one of each of the
five question types, and it gives the statistical weight that the small expert sets cannot.
// CONFIRM: the methodology says 40 Grownfield questions, this says 33. Make both agree.

== Retrieval Results

Retrieval decides what the generator can use, and a weak retrieval stage limits every answer
that follows. Two things matter here. The golden document should rank high, and it should stay
inside the top results that the generator reads. Position and coverage are both measured, using
Hit\@k and mean reciprocal rank as defined in the theory chapter. Hit\@k checks whether a golden
document appears in the top $k$, and mean reciprocal rank rewards a golden document that is
placed near the top and not only inside the window.

Three comparisons follow. The first holds the entity seeds fixed and changes only the graph
traversal engine, so that the effect of traversal depth and Personalized PageRank can be seen on
its own. The second sets vector, graph and hybrid retrieval against each other. The third
measures the change from AVAILABLE 1.0 to AVAILABLE 2.0 on the same task.
// TODO: the third comparison (AVAILABLE 1.0 versus 2.0) is not written yet. Send the numbers.

=== Graph Engine Selection

The graph traversal engine was chosen on a fixed set of Grownfield questions. Every candidate
received the same entity seeds, so only the traversal step changed. Three strategies were
compared, a single entity hop, an entity traversal over three hops, and Personalized PageRank over
the same seeds. @fig-engines reports the outcome.
// TODO: add the number of questions used for this comparison.

#figure(
  image("../figures/graph-engine-comparison.png", width: 90%),
  caption: [Graph retrieval quality by traversal engine, with identical entity seeds for all
  three engines.],
) <fig-engines>

The single hop was the most precise at the top. It placed the correct document at rank one most
often, with a Hit\@1 of 0.41, and it reached the highest MRR of 0.54. The three hop strategy
performed worse on every measure, with a Hit\@10 of 0.52 against 0.72 for the single hop, so
stepping further out found fewer correct documents and mostly pulled in noise. Personalized
PageRank spread weight across the whole graph instead of taking fixed steps. It was weaker at rank
one, with a Hit\@1 of 0.31, but it recovered the most correct documents overall. Its Hit\@5 and
Hit\@10 were both 0.76, which is higher than the 0.69 and 0.72 of the single hop.

The choice came down to two strengths. The single hop is precise at the very top, while
Personalized PageRank reaches wider. The graph leg does not produce the final answer. Its results
pass to a reranker that re-scores every candidate at the end. A reranker can reorder the documents
it receives, but it cannot recover a correct document that was never retrieved. A wider reach
therefore matters more than a clean top rank at this stage. For that reason Personalized PageRank
was carried forward into the combined system. Because the reranker fixes the ordering later, the
task of the graph leg is to catch as many correct documents as possible, and Personalized PageRank
catches more.

=== Vector, Graph and Hybrid Retrieval

Three retrieval settings are compared. Vector retrieval ranks by dense similarity. Graph retrieval
ranks by Personalized PageRank over the entity graph. Hybrid retrieval joins both candidate sets
and passes the pool on to the reranker. @fig-legs reports Hit\@10 and mean reciprocal rank for the
three settings.
// CONFIRM: which dataset and how many questions this figure uses. The graph values match the PPR bars above, so I assumed the same Grownfield questions.

#figure(
  image("../figures/retrieval-legs-comparison.png", width: 75%),
  caption: [Retrieval quality of the vector, graph and hybrid legs, measured by Hit\@10 and mean
  reciprocal rank.],
) <fig-legs>

Vector retrieval does most of the work. It reaches a Hit\@10 of 0.86 and an MRR of 0.69, because the
question and the document often use the same words, so similarity search finds the right chunks on
its own. Graph retrieval alone is the weakest of the three, with a Hit\@10 of 0.76 and an MRR of
0.48, and the gap in MRR is large. A likely reason is that Personalized PageRank can only start
from the entities named in the question, so a question without clear entities gives it almost
nothing to work with. A retriever that depends on named entities cannot stand alone when many
questions are worded loosely @gutierrez2025. The standalone score is therefore not a judgement on
the graph as such. It shows why the graph alone is not sufficient for retrieval.

At the same time, the graph helps the hybrid setting to reach a much wider window than vector
alone. Hit\@10 rises from 0.86 to 0.97, an increase of eleven percentage points, while MRR rises
only from 0.69 to 0.73. What the graph adds is therefore mainly recall and only slightly a better
ordering. For a stage that feeds a reranker this is the right trade. The reranker can reorder
anything that is already in the pool, but it can do nothing for a chunk that the pool never held.
Letting more correct chunks into the pool is the more useful outcome.

Overall, the picture is steady. Vector retrieval sets the top rank and does most of the work. The
graph leg adds recall that vector search misses. Hybrid keeps that gain and also ranks slightly
better than vector alone. For a pipeline that passes its pool to a reranker, this is the retriever
worth keeping. It widens what the reranker can choose from and leaves the parts that already work
alone.

=== Reranker Ablation

The reranker is one of the most expensive components of the query time flow. To see what it
adds, the Grownfield questions were run three times, once without a reranker, once with
bge-reranker-base and once with bge-reranker-v2-m3. Only the reranker changed between the runs.
The graph engine, the fusion and the language model stayed the same. All times were measured on
a CPU, with one run per configuration.

==== Time per Question

@fig-latency-components splits the time per question for the v2-m3 configuration into its
components. The vector leg takes 2.3 s, the graph leg 5.0 s and the generation 6.3 s. The
reranker takes 15.3 s, which is more than half of the total of 28.9 s. It is the largest single
cost of the pipeline.

#figure(
  image("../figures/latency-components.png", width: 70%),
  caption: [Mean time per question by component with bge-reranker-v2-m3.],
) <fig-latency-components>

@tab-reranker-time compares the three configurations. Without a reranker a question takes about
13.4 s. The base reranker adds about 4.4 s, which is a third more. The v2-m3 reranker adds about
15.5 s and more than doubles the time.

#figure(
  thesis-table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    header: ([Configuration], [Time per question (s)], [Extra time (s)]),
    [No reranker], [13.4], [-],
    [bge-reranker-base], [17.8], [+4.4],
    [bge-reranker-v2-m3], [28.9], [+15.5],
  ),
  kind: table,
  caption: [Mean time per question for the three reranker configurations.],
) <tab-reranker-time>

==== Retrieval Quality

@fig-reranker-retrieval shows that the reranker does not change retrieval much. MRR stays at
0.73 to 0.74 for all three configurations. Hit\@3 rises from 0.76 to 0.79 with the base reranker
and is 0.76 again with v2-m3. Hit\@1 is 0.66 without a reranker and with the base reranker, and
falls to 0.62 with v2-m3. With 29 questions, one question is worth about 0.03, so each of these
differences is a single question. They are too small to say that one configuration retrieves
better than another.

#figure(
  image("../figures/reranker-retrieval.png", width: 80%),
  caption: [Retrieval quality by reranker, measured with MRR, Hit\@1 and Hit\@3.],
) <fig-reranker-retrieval>

==== Answer Quality

@fig-reranker-ragas gives the four RAGAS measures for the hybrid leg. Context precision shows the
clearest change. It rises from 0.77 without a reranker to 0.83 with the base reranker and to 0.90
with v2-m3. The other measures change very little. Faithfulness is 0.87, 0.92 and 0.91, answer
relevancy is 0.91, 0.88 and 0.90, and context recall is 0.80, 0.83 and 0.82. The reranker
therefore places the relevant chunks higher in the list, but the answers themselves hardly
improve.

#figure(
  image("../figures/reranker-ragas.png", width: 90%),
  caption: [RAGAS generation quality by reranker for the hybrid leg.],
) <fig-reranker-ragas>

==== Quality against Time

@fig-reranker-scatter puts answer quality, the average of faithfulness and answer relevancy,
against the time per question. The average is 0.894 without a reranker, 0.900 with the base
reranker and 0.904 with v2-m3. The gain is 0.006 and 0.011, while the time grows by 4.4 s and
15.5 s. Answer quality is almost flat, and the time per question is not. This is why the
reranker was switched off in the final system.

#figure(
  image("../figures/reranker-scatter.png", width: 75%),
  caption: [Answer quality against time per question for the three reranker configurations.],
) <fig-reranker-scatter>

=== AVAILABLE 1.0 vs AVAILABLE 2.0

The last comparison sets the baseline against the final system. AVAILABLE 1.0 ran a single vector
retrieval pipeline, so it is compared with the hybrid setting of AVAILABLE 2.0, with fusion but
without the reranker, matching the final system. The comparison is shown for each dataset in turn.

On Grownfield, the multi document reasoning set, the gain is large at every cutoff
(@fig-ret-grownfield). Hit\@1 rises from 0.39 to 0.66, so the correct document now leads the
results far more often. The mean reciprocal rank rises from 0.46 to 0.73, and Hit\@10 rises from
0.74 to 0.93. The first version left about a quarter of the questions without a correct document
in the top ten, and the second version reduces this share to 7 percent.

#figure(
  image("../figures/retrieval_grownfield.png", width: 85%),
  caption: [Retrieval quality of AVAILABLE 1.0 and AVAILABLE 2.0 on Grownfield.],
) <fig-ret-grownfield>

On Hydraulics the second version is close to perfect (@fig-ret-hydraulics). Hit\@1 rises from 0.68
to 0.95, and Hit\@3 and Hit\@10 both reach 1.00, so the golden document is always among the top
three results. The mean reciprocal rank rises from 0.73 to 0.97. The baseline already found the
right document for most questions, but it often ranked it low, and most of the gain here comes from
ranking.

#figure(
  image("../figures/retrieval_hydraulics.png", width: 85%),
  caption: [Retrieval quality of AVAILABLE 1.0 and AVAILABLE 2.0 on Hydraulics.],
) <fig-ret-hydraulics>

On the synthetic set the gain is smaller but consistent (@fig-ret-synthetic). Hit\@1 rises from
0.56 to 0.68, Hit\@10 from 0.83 to 0.92, and the mean reciprocal rank from 0.65 to 0.77. A likely
reason for the smaller gain is that these questions were generated from the documents themselves
and therefore share much of their wording, which favours a simple similarity search. The baseline
is already strong here, so there is less room to improve.

#figure(
  image("../figures/retrieval_synthetic.png", width: 85%),
  caption: [Retrieval quality of AVAILABLE 1.0 and AVAILABLE 2.0 on the synthetic set.],
) <fig-ret-synthetic>

Across the three datasets the picture is the same. AVAILABLE 2.0 is better on every dataset and on
every measure. The largest gains are at the top of the ranking, which matters most in practice,
since passages at the top of the context are the ones that the generator uses best @liu2024. The
wider reach also removes a hard limit. A document that never enters the window can never be used,
and the second version reduces the share of questions without a correct document in the top ten
from between 17 and 26 percent to between 0 and 8 percent.

This comparison measures the redesign as a whole. The new embedding model, the new vector store,
the graph leg, the fusion and the reranker all changed together, so the figures show what the
second version achieves but not how much each change contributed.

== Generation Results

Generation is scored with the four RAGAS measures introduced in the methodology. @fig-ragas reports
them for the hybrid leg on Grownfield.
// CONFIRM: that this figure uses the Grownfield expert questions, and add the other legs and datasets if you have them.

#figure(
  image("../figures/ragas-generation-grownfield.png", width: 75%),
  caption: [RAGAS generation quality of the hybrid leg on Grownfield.],
) <fig-ragas>

The two measures that judge the answer are high. Faithfulness is 0.917, so about nine in ten
claims of the generated answers are supported by the retrieved context, and answer relevancy is
0.927, so the answers stay on the question that was asked. The two measures that judge the context
are lower. Context precision is 0.876, which means that most retrieved passages are relevant and
that they appear near the top. Context recall is the lowest at 0.792, which means that in about one
fifth of the claims of the reference answers, the retrieved context did not hold the information
that was needed. This points to retrieval as the main remaining limit and not to the generator. The
standalone scores in @fig-ragas use the original Grownfield question set, while the AVAILABLE 1.0
versus 2.0 comparison below was run after the Grownfield team added a few further questions, which is
why the AVAILABLE 2.0 values differ between the two figures.

=== AVAILABLE 1.0 vs AVAILABLE 2.0

This comparison sets AVAILABLE 1.0 against AVAILABLE 2.0 on the same four RAGAS measures. The
language model that writes the answer is the same in both versions, so any difference comes from the
context that it receives.

On Grownfield, the context measures improve the most (@fig-gen-grownfield). Context precision rises
from 0.36 to 0.77 and context recall from 0.52 to 0.80. This follows from the retrieval changes.
The reranked pool puts relevant passages at the top, which raises precision, and the wider reach of
the hybrid setting brings in more of the information that is needed, which raises recall. The answer
measures improve by less, with faithfulness rising from 0.83 to 0.87 and answer relevancy from 0.86
to 0.91. The baseline answers were already reasonably faithful, and the better context mainly
removes noise.

#figure(
  image("../figures/generation_grownfield.png", width: 85%),
  caption: [RAGAS generation quality of AVAILABLE 1.0 and AVAILABLE 2.0 on Grownfield.],
) <fig-gen-grownfield>

Hydraulics shows the largest gains in the answer measures (@fig-gen-hydraulics). Faithfulness rises
from 0.57 to 0.69 and answer relevancy from 0.54 to 0.78, and context precision doubles from 0.32
to 0.68. Context recall rises from 0.41 to 0.59. These are also the lowest scores of the three
datasets for both versions. This is notable because retrieval finds the golden document for every
question here, with a Hit\@3 of 1.00. The remaining limit on this dataset is therefore not finding
the right document. It may lie in which parts of the document reach the model, or in how a judge
model scores German text, but neither is tested here.

#figure(
  image("../figures/generation_hydraulics.png", width: 85%),
  caption: [RAGAS generation quality of AVAILABLE 1.0 and AVAILABLE 2.0 on Hydraulics.],
) <fig-gen-hydraulics>

On the synthetic set both versions score high on the answer measures, and faithfulness hardly moves,
from 0.87 to 0.88 (@fig-gen-synthetic). Answer relevancy rises from 0.92 to 0.95. The context
measures still improve, with context precision rising from 0.66 to 0.84 and context recall from 0.86
to 0.94. The baseline already worked well on these questions, so there is little room left to
improve the answers.

#figure(
  image("../figures/generation_synthetic.png", width: 85%),
  caption: [RAGAS generation quality of AVAILABLE 1.0 and AVAILABLE 2.0 on the synthetic set.],
) <fig-gen-synthetic>

Across the three datasets, the context measures improve the most and the answer measures improve by
less. Better context therefore helps the answer most where the baseline struggled, which is on the
two expert sets.

== Trust Score Validation

The trust score gives each document a reliability value before any question is asked, as described
in the trust scoring section of the methodology. The score has to prove two things. It must move in
the right direction when a document loses quality, and it must help the system choose well when two
documents cover the same topic but only one of them is reliable. Two experiments test these claims
in turn.

Experiment 1 tests validity. Good documents are damaged in controlled ways, the score is computed
again, and the question is whether it notices the damage and points to the part that was harmed.
Experiment 2 tests usefulness. Reliable documents are paired with poisoned twins that share the
topic but carry wrong facts. The score is switched on inside the retrieval and generation pipeline,
and the question is whether it steers the system toward the correct source and the correct answer.

=== Experiment 1, Detecting a Loss of Quality

Four checks are made on the damaged copies described in the methodology. Only the prior is examined
in this experiment. Each table reads one property that the score should have.

#figure(
  thesis-table(
    columns: (1.2fr, 1.6fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, left) + (right,) * 4,
    header: ([Attack], [Target pillar], [Before], [After], [Change], [Drop]),
    [Procedural], [Process completeness], [0.750], [0.682], [−0.068], [−9.0%],
    [Technical], [Technical depth], [0.825], [0.708], [−0.118], [−14.2%],
    [Filler], [Focus], [0.892], [0.767], [−0.125], [−14.0%],
    [Authority], [Authority], [0.932], [0.300], [−0.633], [−67.8%],
    [Freshness], [Freshness], [0.914], [0.363], [−0.551], [−60.3%],
  ),
  kind: table,
  caption: [Score of the targeted pillar before and after each attack.],
) <tab-attack-pillar>

@tab-attack-pillar tests the most basic question. When an attack targets one pillar, does that
pillar fall. It does in every case, so the score reacts to the kind of damage that it is meant to
catch. The two metadata attacks fall the most, because they change a field outright and leave
nothing behind to hold the score up. The content attacks fall less, since a language model that
rewrites a document still leaves some real quality in the text. The score drops without going to the
floor. This first check matters most, because a quality signal that did not move under real damage
would be no signal at all.

#figure(
  thesis-table(
    columns: (1.4fr, 1fr, 1fr, 1fr, 1fr),
    align: (left,) + (right,) * 4,
    header: ([Attack], [Before], [After], [Change], [Drop]),
    [Procedural], [0.872], [0.848], [−0.023], [−2.7%],
    [Technical], [0.872], [0.837], [−0.034], [−3.9%],
    [Filler], [0.872], [0.822], [−0.049], [−5.7%],
    [Authority], [0.872], [0.714], [−0.158], [−18.1%],
    [Freshness], [0.872], [0.789], [−0.083], [−9.5%],
  ),
  kind: table,
  caption: [Overall prior before and after each attack.],
) <tab-attack-prior>

@tab-attack-prior moves from a single pillar to the full prior. The goal is to see whether one
damaged pillar drags the whole score down or only part of it. Every prior falls by less than its
pillar did, because the other pillars hold up the rest of the score. How far the prior falls follows
the weight of the damaged pillar. For the authority attack the pillar fell by 0.633 and has a weight
of 0.25, which gives $0.25 times 0.633 = 0.158$, exactly the change in the table. The freshness
attack gives $0.15 times 0.551 = 0.083$ in the same way. Replacing a known author with an unknown one
therefore pulls the prior down by a clear amount, which is the right reaction for Bosch training
material, where documents from approved internal sources should count for more than unknown ones.
The wider point is that a document with one weak spot loses some trust and not all of it, so the
score does not treat a small fault as a total failure.

#figure(
  thesis-table(
    columns: (1.4fr, 1.2fr, 1.4fr, 1fr),
    align: (left,) + (right,) * 3,
    header: ([Attack], [Technical depth], [Process completeness], [Focus]),
    [Procedural], [−0.035], [*−0.068*], [−0.040],
    [Technical], [*−0.118*], [−0.065], [−0.043],
    [Filler], [−0.083], [−0.113], [*−0.125*],
  ),
  kind: table,
  caption: [Change of each content sub-score under the three content attacks. The largest fall in each row is in bold.],
) <tab-attack-sub>
// TODO: the methodology lists four content ratings (depth, completeness, usability, focus). Usability is missing here. Add the column or say why it is left out.

@tab-attack-sub asks whether the damage stays where it was aimed. For each content attack the
biggest fall lands on the sub-score that it was meant to hurt. This shows that the sub-scores measure
separate things and not one blurred sense of quality that slides together no matter what is broken.
The other sub-scores also fall to some degree, which is expected, since a damaged text is rarely
damaged in one way only. The filler attack is the weakest case, where the fall in process
completeness, at 0.113, is almost as large as the fall in focus, at 0.125. Even so, the score can
point to what is mostly wrong with a document and does not only report that it is worse.

#figure(
  thesis-table(
    columns: (1.3fr, 1fr, 1.2fr, 1.6fr, 1fr, 1fr),
    align: (left,) + (right,) * 5,
    header: ([Attack], [Dropped], [Median change], [95% CI], [$d$], [$p_"BH"$]),
    [Procedural], [20 of 40], [−0.050], [[−0.100, −0.037]], [−0.68], [0.0001],
    [Technical], [29 of 40], [−0.100], [[−0.155, −0.083]], [−1.00], [$< 0.0001$],
    [Filler], [25 of 40], [−0.100], [[−0.180, −0.075]], [−0.72], [0.0001],
  ),
  kind: table,
  caption: [Wilcoxon signed rank tests of the targeted content sub-scores. The column $p_"BH"$ gives the p-value after the Benjamini Hochberg correction for the three tests.],
) <tab-attack-stats>
// CONFIRM: I read the Dropped column as the number of documents where the targeted sub-score fell.

@tab-attack-stats confirms that the content drops are real and not chance. Every content attack
lowers its targeted sub-score with a clear effect, and the effect sizes are medium to large, with
Cohen's $d$ between 0.68 and 1.00. The technical attack is the strongest of the three. The procedural
attack is the weakest, since its sub-score fell in only half of the documents. The confidence
intervals stay clear of zero throughout, and the result holds after correcting for the three tests
that were run together. The metadata attacks need no test, since they change a field outright and
their effect is certain by construction. This gives the earlier tables statistical backing, so the
drops can be read as the score working and not as noise in the scorer.

Across all four checks the score behaves as a valid signal should. It reacts to deliberate quality
loss, spreads that loss sensibly across the prior, keeps it mostly local to the right sub-score, and
does so with statistical support. Validity is established. That is the precondition for the next
question, whether a valid score is also useful once it is switched on inside the live system.

=== Experiment 2, Helping the RAG

The setup is the corpus of good documents and poisoned twins described in the methodology. The score
is read at two layers, retrieval and generation, across three arms. In the first arm trust is off, in
the second only the prior is used, and in the third the full score of prior and support is used.

==== Retrieval

#figure(
  thesis-table(
    columns: (1.5fr, 0.7fr, 1.5fr, 1.5fr, 1fr, 1.2fr),
    align: (left,) + (right,) * 5,
    header: ([Arm], [$N$], [Good above twin], [Twin above good], [Neither], [Good first]),
    [Trust off], [190], [73], [82], [35], [38.4%],
    [Prior], [190], [*135*], [*20*], [35], [*71.1%*],
    [Full score], [190], [124], [31], [35], [65.3%],
  ),
  kind: table,
  caption: [Ranking of the good document against its poisoned twin. The best value in each column is in bold.],
) <tab-ret-trust>

@tab-ret-trust asks the first question. When a good document and its poisoned twin both reach the
pool, does the good one rank higher. With trust off the answer is often no. The good source leads for
well under half of the questions, and the twin wins more often than the good document does. This is
the exact failure that the trust score exists to fix, because the twin shares the topic and the
wording, so plain relevance cannot tell the two apart. Turning on the prior changes the picture
sharply. The share of questions where the good document comes first almost doubles, and the wins of
the twin drop to a fraction of what they were. The full score helps too, but it lands below the
prior. One block of 35 questions stays the same across all three arms, the ones where neither
document is retrieved at all. Trust can reorder the pool, but it cannot bring back a document that
retrieval never found.

#figure(
  thesis-table(
    columns: (1.8fr, 0.6fr, 0.6fr, 1fr, 1.2fr, 1fr),
    align: (left,) + (right,) * 4 + (left,),
    header: ([Comparison], [$b$], [$c$], [$chi^2$], [$p$ (exact)], [Better]),
    [Off versus prior], [0], [62], [60.016], [$< 0.0001$], [Prior],
    [Prior versus full], [11], [0], [9.091], [0.0010], [Prior],
    [Off versus full], [4], [55], [42.373], [$< 0.0001$], [Full],
  ),
  kind: table,
  caption: [McNemar tests of the retrieval result. The column $b$ counts questions that the first arm gets right and the second gets wrong, and $c$ counts the opposite.],
) <tab-ret-mcnemar>

@tab-ret-mcnemar checks these shifts with a paired test. Both trust arms beat the off arm by a wide
and clear margin. The split between off and prior runs one way only. Many questions flip to the good
source once the prior is on, and none flip back. The comparison of prior and full favours the prior,
since adding the support score pushes some questions back to the twin and rescues none. At the
retrieval layer the prior therefore carries the whole benefit, and the support score takes a little
of it away.

==== Generation

#figure(
  thesis-table(
    columns: (1.6fr, 1fr, 1fr, 1fr),
    align: (left,) + (right,) * 3,
    header: ([Grader], [Trust off], [Prior], [Full score]),
    [Exact match], [63.2%], [*70.0%*], [64.2%],
    [LLM judge], [41.1%], [*70.0%*], [63.7%],
    [RAGAS], [21.1%], [18.9%], [19.5%],
  ),
  kind: table,
  caption: [Share of correct answers by grader and arm. The best value per row is in bold, except for RAGAS, which was found to be unreliable.],
) <tab-gen-graders>

@tab-gen-graders moves to the written answer. The question now is whether the answer follows the
correct value or the wrong value of the twin. Two of the three graders, exact match and the language
model judge, put the prior arm highest and agree closely on the two trust arms. They differ on the
arm with trust off, for a reason that @tab-answer-outcomes makes clear. RAGAS sits far lower and
hardly moves across the arms, which is a warning that this grader is not reading the task.

#figure(
  thesis-table(
    columns: (2fr, 1fr, 2fr),
    align: (left, right, right),
    header: ([Grader], [$N$], [Agreement with ground truth]),
    [LLM judge], [570], [*86.1%*],
    [RAGAS], [570], [46.0%],
  ),
  kind: table,
  caption: [Agreement of the two model based graders with the known correct value. The count is 190 questions in three arms.],
) <tab-grader-check>

@tab-grader-check follows up on that warning by checking each grader against the known correct value.
The language model judge agrees with the ground truth on most answers. RAGAS agrees on less than half,
close to a coin flip. RAGAS answer correctness is built for longer generated text, and it misreads
the short factual answers used here. For that reason exact match is kept as the main grader and RAGAS
is set aside. This step matters, because trusting RAGAS would have buried the real effect under a
grader that cannot see it.

#figure(
  thesis-table(
    columns: (1.6fr, 1fr, 1fr, 1fr, 1fr),
    align: (left,) + (right,) * 4,
    header: ([Arm], [Correct], [Poisoned], [Both], [Missing]),
    [Trust off], [78], [17], [42], [53],
    [Prior], [*132*], [*7*], [*1*], [50],
    [Full score], [118], [13], [4], [55],
  ),
  kind: table,
  caption: [How the answers of each arm fall into four outcomes, out of 190 questions. The best value in the first three columns is in bold.],
) <tab-answer-outcomes>

@tab-answer-outcomes splits each arm into the four ways an answer can land. It can name the correct
value only, the wrong value only, both values, or neither. The exact match grader counts an answer as
correct when it contains the correct value, so the hedged answers in the third column also count as
correct under it. This is why the arm with trust off scores 63.2% in the exact match row, although
only 78 of its 190 answers name the correct value alone. The prior gives the largest gain. Answers
that give only the correct value rise by a big step, and answers that follow the wrong value fall to
a handful. The clearest shift is in the third column. With trust off the model often hedges and names
the right value and the wrong value together instead of choosing. Once the prior tags the trusted
chunk in the prompt, that hedging almost vanishes and the model commits to the correct source. This
is the practical payoff. Trust does not only reorder documents, it gives the generator a reason to
pick one source when two disagree. The full score again improves on the baseline without trust but
trails the prior.

#figure(
  thesis-table(
    columns: (1.8fr, 0.6fr, 0.6fr, 1fr, 1.2fr, 1.4fr),
    align: (left,) + (right,) * 4 + (left,),
    header: ([Comparison], [$b$], [$c$], [$chi^2$], [$p$ (exact)], [Better]),
    [Off versus prior], [4], [17], [6.857], [0.0072], [Prior],
    [Prior versus full], [13], [2], [6.667], [0.0074], [Prior],
    [Off versus full], [13], [15], [0.036], [0.8506], [No difference],
  ),
  kind: table,
  caption: [McNemar tests of the answer correctness under exact match.],
) <tab-gen-mcnemar>

@tab-gen-mcnemar tests the answer outcomes with the same paired test. The prior significantly improves
correctness over the baseline without trust. The prior also beats the full score, since a group of
questions are correct under the prior but wrong once the support score is added. The comparison of
off and full is not significant, and that is the sharpest result in the table. On its own, the full
score does not reliably beat using no trust at all.

Both layers read the same way. The prior, built from content and metadata, does the useful work. It
ranks the trusted source above its twin and steers the answer to the right value. The support score
adds nothing beyond the prior and takes a little away. The likely reason lies in the test itself, as
discussed in the next subsection.

=== Why the Full Score Trails the Prior

A twin is almost a copy of its good document. The attack flips about ten facts and weakens the
metadata, and the rest stays the same, so the two documents look nearly identical. The prior reads
the document itself, its weak metadata and its content, which is where the good document and the twin
differ, so it separates them cleanly. The support score measures corroboration, meaning how well a
document connects to other trusted documents, and it checks agreement and not truth, as discussed in
the limits of the method in the methodology. Because the twin is a near copy, it probably sits in the
same part of the graph as the original and looks just as well supported, so the support score cannot
tell them apart. Blending the two then leaves the full score weaker than the prior alone, which is
why some orderings and answers fall back to the wrong source once the support score is added. This
explanation fits the data, but it was not tested separately here. It also fits the choice made in the
methodology to give the support score a weight of only 0.3, so that it can nudge a score but not
override the prior.

One point keeps this in perspective. This is the hardest case for the support score by design, since
the twins are near duplicates. For a truly isolated junk document, with no shared terms and no graph
links, the support score would be expected to give a low value and to help. This experiment does not
test that case. Against copy and paste poisoning it cannot help, because agreement alone cannot punish
a wrong fact that reuses real terms.

== Observability Dashboard
