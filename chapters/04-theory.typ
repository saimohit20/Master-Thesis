= Theory

== LLM and RAG Background

Large Language Models (LLMs) are neural networks trained on very large amounts of text
to predict the next word in a sentence. They are built on the Transformer architecture,
which processes text as a sequence of tokens and uses a mechanism called self-attention
to weight how strongly each token influences every other token @vaswani2017. During
training, the model is repeatedly given a piece of text with the next word hidden, and
it learns to predict that word by adjusting billions of internal parameters, also
called weights. Once training is finished, this knowledge is fixed. The model has no
separate memory and can only generate text from the patterns already stored in its
parameters.

This creates a problem for company use. An LLM is not trained on the private documents
of a company, such as internal machine manuals or training material. When it is asked
about something outside its training data, the model often produces an answer that is
fluent and confident but factually wrong. This behaviour is called hallucination #footnote[need to add] @fan2024.

Retrieval-Augmented Generation (RAG) was introduced to address this problem
@lewis2020. Instead of relying only on what the model has memorised, a RAG system first
searches an external knowledge base for passages that are relevant to the question and
then passes those passages to the LLM as context. The LLM is instructed to base its
answer on this retrieved context and not on its own parameters.

A basic RAG pipeline consists of three stages that build on one another. The first
stage is indexing. The knowledge base, in this case the Bosch Rexroth training
documents, is split into smaller pieces ahead of time and stored in a form that can be
searched efficiently. When a user question arrives, the retrieval stage searches this
index and returns the pieces judged most relevant to the question. In the generation
stage, the LLM receives the original question together with the retrieved pieces and
produces an answer grounded in them.

This basic setup raises two further questions that the rest of this chapter addresses.
The first is how the retrieval stage should decide what counts as relevant. The second
is how the system should judge whether a retrieved document can be trusted in the first
place.

== Retrieval Methods

=== Vector Retrieval

Vector retrieval works by turning text into a numerical form that captures meaning, so
that pieces of text with similar meaning end up close together in a shared space. This
numerical form is called an embedding, a fixed-length list of numbers produced by an
embedding model, such that texts about the same topic map to nearby points even when
they use different words. This is what lets vector retrieval match a question to a
passage without the two sharing the same vocabulary, a property that earlier
keyword-based search methods lacked @karpukhin2020.

At index time, every chunk of the knowledge base is passed through an embedding model
and the resulting vector is stored in a vector database. At query time, the user's
question is embedded in the same way, and the database returns the chunks whose vectors
are closest to the question's vector, usually measured by cosine similarity
#footnote[need to add].

This meaning-based approach, known as dense retrieval, has a known weakness. Because it
matches on overall meaning, it can blur the difference between two texts that are
semantically similar but differ in a specific detail, such as an exact code, a part
number or a technical term @fan2024. To address this, dense retrieval is often paired
with sparse retrieval, an older approach that scores text by exact word overlap,
weighted by how rare or informative each word is @robertson2009. Sparse retrieval is
weaker at capturing meaning but stronger at catching the exact terms that dense
retrieval can miss.

Modern embedding models such as BGE-M3 combine both signals. From the same input and in
a single pass they produce a dense vector for meaning and a sparse vector for exact
terms, rather than needing two separate models @chen2024. When both result lists are
available, they are commonly merged using reciprocal rank fusion, a method that
combines rankings based on each item's position in each list rather than its raw score,
which avoids comparing two differently scaled similarity scores directly @cormack2009.

=== Graph Retrieval

Vector retrieval treats every chunk as an independent piece of text and scores it in
isolation. This is a limitation when the answer to a question is not contained in a
single passage but depends on how two separate pieces of information are connected. A
knowledge graph addresses this by representing information as a set of nodes connected
by edges. Nodes typically stand for entities, such as a part name, a process or a
document, and edges represent the relations between them @hogan2021. Because relations
are stored explicitly, a graph can link two passages that discuss the same underlying
concept even when they share little vocabulary, which is exactly the case dense vector
search tends to miss.

Building a graph for retrieval usually involves an extraction step. A language model
reads the text and identifies the entities it mentions and the relations between them,
which are then merged so that the same entity mentioned in different places becomes a
single node @edge2024. Each chunk is linked to the entities it mentions, so a query can
be matched to a small set of relevant entities first and then extended outward to the
chunks connected to them.

Not every entity is equally informative. An entity that appears in almost every
document, such as a generic term, says little about what makes a specific question
distinctive, while a rare, specific entity narrows things down far more. This is
captured by inverse document frequency (IDF), which assigns higher weight to entities
that occur in fewer documents @sparckjones1972. Query entities are therefore weighted by
a combination of how confidently they were matched and how specific they are, so that
rare, precise concepts have more influence on retrieval than common ones.

Once the graph is built, there are different ways to spread relevance from a query's
matched entities to the chunks that should be retrieved. The simplest approach, entity
hop, follows the direct edges from a matched entity to the chunks that mention it, and
optionally repeats this for a fixed number of hops. This works well when the answer
sits close to the matched entity, but it treats each step as an isolated jump and does
not consider how well connected a chunk is within the graph as a whole.

A more general approach is Personalized PageRank (PPR), which extends the original
PageRank algorithm used to rank web pages by their incoming links @page1999. Instead of
measuring importance in a generic, query-independent way, PPR restarts the random walk
at a fixed set of seed nodes, so that importance is measured relative to a specific
starting point rather than the whole graph @haveliwala2002. Formally this is expressed
as

$ pi = alpha dot.op S dot.op pi + (1 - alpha) dot.op e $

where $pi$ is the importance score of each node, $S$ is the graph's transition matrix,
which describes how weight passes from one node to its neighbours, $e$ is the starting
vector that places weight only on the seed nodes, and $alpha$ is the damping factor,
which controls how far the walk is allowed to spread before it is pulled back to the
seeds @page1999. A higher $alpha$ lets relevance travel further across the graph, while
a lower $alpha$ keeps it concentrated near the original query entities. This restart
mechanism is what lets PPR reach chunks that are several relations away from a seed
entity, a case that plain entity hop tends to miss @gutierrez2024.

=== Hybrid Retrieval

Vector retrieval and graph retrieval each capture a different kind of relevance. Vector
retrieval is strong at matching a question to a passage that expresses the same idea in
different words, while graph retrieval is strong at connecting passages through shared
entities and relations, even when the wording is completely different. Because the two
approaches fail in different situations, combining them tends to recover more relevant
passages than either one alone @sarmah2024. This combination is generally called hybrid
retrieval.

The most direct way to combine two retrieval legs is a union. The top results from each
leg are merged into a single candidate pool, with duplicates removed. A passage
retrieved by both legs is naturally a strong candidate, since two different retrieval
signals agree on it independently. This union step does not try to produce a final
ranking by itself. It only decides which passages are worth considering further and
leaves the actual ordering to a later step.

This later step is needed because the scores from the first-stage retrieval are not
directly comparable and, on their own, are only a rough estimate of relevance. Vector
similarity and graph traversal scores are computed independently and sit on different
scales, and both are produced by comparing the query and each passage separately,
without the two ever being read together. A more precise way to judge relevance is a
cross-encoder. Instead of embedding the query and a passage separately and comparing
their vectors, a cross-encoder takes the query and one candidate passage together as a
single input and directly predicts how well that passage answers the query
@nogueira2019. This joint comparison is considerably more accurate than similarity
search, but it is also far more expensive, since it must run once for every
query-passage pair rather than once per passage in advance. For this reason
cross-encoders are used only as a second, reranking stage, applied to the small
candidate pool returned by the first-stage retrieval rather than to the whole corpus
@gao2023.

Reranking with a cross-encoder also helps counter a separate problem in long-context
generation. Language models do not use all parts of a long context equally well and
tend to pay less attention to information placed in the middle than to information near
the beginning or the end, a pattern known as the lost in the middle effect @liu2024. By
reordering the retrieved passages so that the most relevant ones come first, reranking
reduces the chance that an important passage is overlooked because of where it happened
to fall in the context window.

== Trust Score

Retrieval, as covered in the previous section, is built entirely around relevance. It
asks how closely a passage matches the meaning or the entities of a question. Relevance
alone, however, says nothing about whether a passage can be trusted. Two documents can
be equally relevant to a question while differing sharply in reliability. One might be
a current, expert-authored handbook, and the other an outdated draft from an unknown
author. A retrieval system that only measures relevance cannot tell these apart, which
becomes a real problem in enterprise knowledge bases, where documents accumulate over
time, some maintained carefully and others left unreviewed for years.

This gap has led to two broad ways of estimating how trustworthy a document is.

The first looks at the document on its own, independent of anything else in the corpus.
This content-based view judges a document by properties such as who authored it, how
recently it was updated, how complete and specific its content is, and what format it
is stored in @yu2025trust. These signals are cheap to compute, since each document can
be scored without reference to any other document, but they only capture what can be
observed from the document in isolation.

The second view judges a document by how it relates to the rest of the corpus, an idea
that originates from web search. Early search engines faced a similar problem with
spam. A page could rank highly by relevance while containing unreliable or manipulated
content. TrustRank was introduced to address this by propagating trust through
hyperlinks rather than judging every page in isolation @gyongyi2004. A small set of
pages is first labelled as trustworthy by a human reviewer, and trust then spreads
outward along links using the same mathematical process as PageRank, so that a page
linked to by many trustworthy pages accumulates higher trust than a page with no such
connections @page1999. The underlying assumption is that trustworthy sources tend to
reference other trustworthy sources, so corroboration itself carries information about
reliability.

This idea has since been adapted from web pages to documents in a retrieval corpus.
Instead of hyperlinks, a document-to-document graph is built from shared content, such
as entities or claims that appear in more than one document, and trust is propagated
across this graph in the same way it propagates across links on the web. ClaimTrust
applies this by checking whether claims in one document are supported or contradicted by
claims in others, which allows trust to rise when information is independently
corroborated @qian2025. RAGRank instead combines a document's authority with its
retrieval similarity, so that documents with lower credibility are down-weighted before
they are selected @jia2025. Both approaches share the logic of TrustRank. Trust is not
only a property of a single document, but something that can flow from reliable sources
to the documents connected to them.

In practice, content-based and propagation-based signals are complementary rather than
competing. A document with strong content and metadata but no connections to the rest
of the corpus still deserves a reasonable trust estimate, while a document that is well
corroborated by other trustworthy sources provides evidence beyond what its own content
reveals. Combining the two into a single score, typically by using the content-based
estimate as a starting point and adjusting it through propagation across the corpus,
lets a trust score be computed automatically for every document without relying on
manual review @yu2025trust.

== Evaluation Metrics

Building an improved retrieval and trust system is only useful if its effect can be
measured. Evaluation in a RAG pipeline is generally split into two separate questions,
because retrieval and generation can each fail independently of the other @yu2025eval.
The first question is whether the system found the right document at all. This is a
retrieval question, and it can be checked automatically once the correct source for a
question is known in advance. The second question is whether the answer written from
that document is actually good. This is a generation question, and it is harder to check
automatically, since the same fact can be phrased correctly in many different ways. This
section introduces the metrics used for each of these two questions in turn.

=== Retrieval Evaluation Metrics

Retrieval metrics assume that, for a given question, one or more documents are already
known to be the correct source, commonly called the golden document. Retrieval is then
evaluated by checking where this golden document falls in the ranked list the system
returns, rather than by judging the retrieved text itself @manning2008.

The simplest such metric is Hit\@k, which checks whether the golden document appears
anywhere within the top $k$ results returned for a question.

$ "Hit@k" = 1/N sum_(i=1)^N bb(1)[r_i <= k] $

Here $r_i$ is the rank at which the golden document was found for question $i$, $N$ is
the number of questions, and the indicator function returns 1 if the golden document
falls within the top $k$ and 0 otherwise @manning2008. Hit\@k is usually reported at
more than one cutoff, since a small $k$, for example Hit\@1, tests strict precision at
the very top of the ranking, while a larger $k$, for example Hit\@10, tests whether the
document is found anywhere within a wider window. The wider window matters more when
several passages are passed on to generation rather than just one.

Hit\@k treats every rank within the cutoff equally. Whether the golden document appears
at rank 1 or rank 10, Hit\@10 scores both cases the same. This can hide a meaningful
difference, since a document ranked first is more useful to a downstream reranker or
generator than one buried near the bottom of the window. Mean Reciprocal Rank (MRR)
addresses this by rewarding a higher position directly.

$ "MRR" = 1/N sum_(i=1)^N 1/r_i $

A golden document found at rank 1 contributes a full point, one found at rank 2
contributes one half, and a question for which the golden document is never retrieved
contributes nothing @manning2008. MRR is therefore a stricter measure than Hit\@k. Two
systems can have identical Hit\@10 scores while differing considerably in MRR, if one
of them consistently ranks the correct document closer to the top.

A related measure is Recall\@k, which is close to Hit\@k but generalises it to the case
where a question may have more than one correct document. It measures what fraction of
all correct documents were found within the top $k$, rather than just whether one was
found. Together, Hit\@k, MRR and Recall\@k give a view of retrieval quality from two
angles, whether the correct evidence is found at all, and how well it is ranked once it
is found.

=== Generator Evaluation Metrics

Retrieval metrics can confirm that the correct document was found, but they say nothing
about the text the language model produces from it. A model can be given the correct
passage and still write an answer that ignores it, misreads it, or adds unsupported
details, so generation has to be evaluated separately, on the answer itself rather than
on the ranking that produced its context @yu2025eval. Because a correct answer can be
phrased in many different ways, it cannot be checked by simple string matching against a
reference answer the way a golden document can. The common solution is to use another
language model as a judge, an approach shown to align reasonably well with human
evaluation on open-ended text @zheng2023. RAGAS is a framework built specifically for
RAG pipelines that uses this idea to score both the answer and the context it was built
from, rather than treating generation as a single, all-or-nothing outcome @es2024.

RAGAS defines four metrics, two that judge the retrieved context and two that judge the
generated answer.

Context precision measures how much of the retrieved context is relevant, rewarding a
system that places the useful passages near the top of the context rather than mixed in
with irrelevant ones.

$ "Context precision" = (sum_k "Precision@k" dot.op v_k) / ("number of relevant contexts") $

Here $v_k$ is 1 if the passage at rank $k$ is relevant and 0 otherwise @es2024. A low
score here signals that the retrieved context is noisy, even if the correct passage is
present somewhere within it.

Context recall measures whether the retrieved context contains what is needed to answer
the question. The reference answer is broken down into individual claims, and each claim
is checked for support in the retrieved context.

$ "Context recall" = ("ground-truth claims supported by the context") / ("total claims in the ground truth") $

A low score here means part of the needed information was missing from retrieval
altogether, regardless of how well the model writes.

Faithfulness checks whether the generated answer stays grounded in the retrieved
context, rather than adding information the context does not support. The answer is
broken down into individual claims, and each is checked against the context.

$ "Faithfulness" = ("claims in the answer supported by the context") / ("total claims in the answer") $

This is effectively a hallucination check applied directly to generation. A faithful
answer sticks to what the retrieved passages actually say, even if that happens to be
incomplete.

Answer relevancy checks whether the answer addresses the question that was asked,
independent of whether it is faithful to the context. This is measured indirectly. The
judge model generates a small set of questions that the answer appears to be responding
to, and each generated question is compared to the original question by embedding
similarity.

$ "Answer relevancy" = 1/n sum_(i=1)^n cos(q, q_i) $

Here $q$ is the original question and $q_i$ are the questions generated back from the
answer @es2024. An answer that drifts off topic produces generated questions that
diverge from the original, which lowers the score even if the answer is technically
faithful to the context.

Used together, these four metrics separate two failure modes that a single overall
score would blur together. A low context score points to a retrieval problem, while a
low faithfulness or relevancy score points to a generation problem, even when the
correct context was retrieved.

== Observability

A RAG pipeline performs several steps for every single question. It embeds the query,
searches one or more retrieval legs, reranks candidates, folds in additional signals
such as trust, and finally calls the LLM to generate an answer. When a poor answer
comes out at the end, reading that final answer alone does not reveal which of these
internal steps caused the problem. The question may have been misembedded, the correct
document may never have been retrieved, or the document may have been retrieved but the
LLM failed to use it correctly. Without visibility into what happened at each step,
debugging a pipeline like this is largely guesswork.

Observability refers to the practice of instrumenting a system so that its internal
behaviour can be inspected after it runs, rather than only its final output
@kreuzberger2023. In traditional software systems this is often done through logging,
but a multi-step AI pipeline benefits from a more structured form of tracing, since it
needs to preserve not only that a step happened, but also what data flowed into and out
of it, how long it took, what it cost, and how the steps are nested within one another
@moshkovich2025.

This structure is commonly organised into three levels. A span represents a single step
in the pipeline, such as one call to the vector store or one call to the language model,
and records that step's inputs, outputs and duration. A trace represents one complete
request from end to end, made up of all the spans it triggered, arranged in the order
and nesting in which they occurred, so that a single trace shows the full path a
question took through the system. A thread groups multiple traces that belong to the
same session, which matters for systems used conversationally, where a person may ask
several related questions in a row @moshkovich2025.

Recording spans and traces automatically, rather than inserting log statements by hand
at every step, is typically done by wrapping each function of interest so that its
execution is captured without changing how the function itself works. When one such
wrapped function calls another, the resulting spans are nested automatically, which
reconstructs the shape of the pipeline as a tree without any of this structure being
built by hand.

Beyond recording what happened, observability tooling can also attach automated quality
feedback to each trace. An LLM-based judge, of the kind introduced in the generator
evaluation metrics above, can score a completed trace for properties such as
hallucination or context relevance and attach that score directly to the trace it
evaluates, so that quality signals and the technical details of a request are available
together rather than in separate systems.

For a pipeline built from multiple retrieval legs, a reranker and a trust-scoring step,
this kind of tracing is what makes it possible to tell, for any single question,
exactly where in the pipeline an unexpected result originated.

== AVAILABLE 1.0

The system extended in this thesis, AVAILABLE, was developed by the Bosch Rexroth
Academy as an AI-supported learning assistant for on-the-job training
@dommermuth2025. Its purpose is to help employees find and apply relevant company
knowledge without searching manually through scattered documentation, course catalogs
or training portals. The original authors report that such a search can otherwise take
several minutes per query and often returns incomplete results.

AVAILABLE 1.0 offers two modes of interaction, both built on a Retrieval-Augmented
Generation (RAG) approach. The first is a question and answer mode, where a user asks a
question directly and receives a short answer together with references and links back
to the original source material. The second is a guided assistant mode, which first
identifies the learning objective and current knowledge level of the user through a
short dialogue of follow-up questions, and then recommends training content suited to
that level.

The guided assistant mode is implemented as a multi-agent system, coordinated with the
AutoGen framework, with GPT-4o as the underlying language model served through Azure.
Three agents divide the work. A Topic Agent determines what the user wants to learn from
their responses. A Knowledge Agent classifies the expertise of the user into one of
three levels, beginner, advanced or expert, through didactic follow-up questions. A
Curriculum Agent combines both outputs to search for and present suitable content,
together with a reliability rating for each source. Underneath both modes sits a shared
document processing pipeline that generates hierarchical summaries of the training
material. It links specific passages to their broader document context, so that
retrieval can return not only a matching passage but also the surrounding context
needed to interpret it.

Document trustworthiness in this baseline is assessed only heuristically. The original
authors describe the rating as an initial, algorithmically generated estimate that has
not been formally validated. For this reason the system was populated only with
material already known to be reliable, and it was not tested against a mixed corpus of
varying quality. A pilot evaluation on 70 training documents and 60 videos showed clear
efficiency gains over manual search. The time to find a relevant document dropped from
several minutes to a few seconds, at an accuracy above 95% across the tested use cases
@dommermuth2025.

The same evaluation leaves two questions open. The first is how the system should
behave when it meets multiple, possibly contradictory sources. The second is how a
reliable, automated measure of source trustworthiness could be derived in the first
place @dommermuth2025. These two open questions are the direct motivation for the
retrieval and trust scoring work developed in this thesis.
