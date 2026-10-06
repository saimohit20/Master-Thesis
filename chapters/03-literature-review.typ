= Literature Review

Building a reliable enterprise learning assistant depends on the retrieval techniques
that decide what information the system sees before it answers, and on whether that
information can be trusted. This chapter reviews the research behind those techniques.
It moves from the foundations of Retrieval-Augmented Generation, through the retrieval
methods that find the right content, to the trust and evaluation methods that decide
whether the content can be relied on and whether the whole system works.

== Foundations of Retrieval-Augmented Generation

The starting point is Retrieval-Augmented Generation (RAG), a method that lets a
language model pull relevant text from an external knowledge base before answering, so
that its responses are grounded in real documents and not only in what the model
memorised during training @lewis2020. How well this works depends on the retrieval
step. If the right documents are not found, even a strong language model cannot
produce a correct answer. Early RAG systems relied on dense vector retrieval, where
the query and the documents are turned into embeddings and matched by similarity,
usually cosine distance. This captures meaning well, so a question can match a passage
even when the two share no exact words. Dense retrieval has a known weakness, however.
It often struggles with exact keyword matching, out-of-domain terms and domain-specific
acronyms, which are common in technical and enterprise settings @fan2024. Hybrid search
addresses this by combining dense retrieval with sparse, keyword-based retrieval, so
that the system benefits from both semantic understanding and exact lexical matching.
This combination has been shown to improve both recall and precision @zhu2023.

== Retrieval with Embeddings, Graphs and Reranking

Achieving this hybrid combination in practice depends on the embedding model, since it
turns both queries and documents into the vectors used for retrieval. Most embedding
models are built for a single type of retrieval, but some support several at once.
BGE-M3 is one such model. Within a single architecture it produces dense, sparse and
multi-vector representations of the same text, so it can serve semantic and
keyword-based retrieval together. Through a training technique called self-knowledge
distillation, it also generalises better across complex retrieval tasks than
traditional dense-only models @chen2024. // TODO footnote 1 from Overleaf goes here

Vector search still treats each chunk of text as an independent point and matches it by
meaning alone. It ignores the connections between pieces of text and the structure of
the documents they come from. For hierarchical or networked information this is a real
limitation, and it has motivated work that combines retrieval with explicit graph
structures. In such systems vector search finds the broad meaning, while the graph
captures exact connections between entities.

Some methods use graphs to capture the structure of a whole corpus. GraphRAG builds a
knowledge graph from the documents, groups related entities into communities and
summarises each one, which helps answer broad questions that plain retrieval handles
poorly @edge2024. RAPTOR follows a similar idea but organises the information as a tree
of summaries, so that the system can retrieve at different levels of detail
@sarthi2024. Both methods first find the right region of the corpus and then retrieve
the specific content within it.

Other methods focus on spreading relevance across the graph. A common starting point is
multi-hop entity traversal, where the system identifies the entities mentioned in the
query and explores their neighbourhood in the graph. By following edges outward it
reaches content that is connected to the query but does not match its wording directly
@sun2018. For this the system first needs to know which entities the query is about. A
common way is to embed every entity, store the embeddings in a vector index, embed the
query with the same model, and select the most similar entities as starting points
@gutierrez2024. From these seed entities, relevance can be propagated more formally
with PageRank, a classic algorithm that ranks nodes by how a random walk moves through
a network @page1999, and with its personalised variant, which pulls the walk toward
the chosen starting nodes @haveliwala2002. HippoRAG builds on this idea. It runs
Personalized PageRank from the entities of the query and gives more weight to rare,
specific terms than to common ones @gutierrez2024. HippoRAG 2 goes further by also
starting the walk from passages found through dense retrieval, which links the graph
more closely to vector search @gutierrez2025.

A well-known example of combining both retrieval types is the HybridRAG framework. It
extracts relational triplets, made of a subject, an action and an object, from
documents to build a knowledge graph alongside the vector database. In experiments on
financial earnings call transcripts it improved both retrieval accuracy and answer
generation over traditional RAG @sarmah2024. Once passages have been retrieved from
both the vector store and the graph, the combined set still needs to be ordered well
before it reaches the language model. Passing a long, unordered list of documents
causes a known problem, because language models tend to ignore information placed in
the middle of a long context and focus on the beginning and the end @liu2024. To avoid
this, an intermediate reranking step is used, typically with a cross-encoder model.
The first retrieval stage scores each document independently of the query, whereas a
cross-encoder reads the query and a document together and judges how well they match
@gao2023. This pushes the most relevant passages to the top, so the language model
receives clean, well-ordered context instead of a noisy list.

Across these graph methods, most systems use either a semantic graph of entities or a
structural graph of the document hierarchy, but rarely both together. They are also
usually tested on multi-hop questions, where the answer is spread across several
documents, and not on the single-hop lookups that are common in enterprise
documentation. This leaves open how graph retrieval performs when both signals are
combined and tested on a real enterprise knowledge base, which is one of the focus
areas of this thesis.

== Trust and Reliability of Source Documents

Good retrieval finds relevant documents, but relevance alone does not guarantee that a
document is reliable. RAG improves answers by grounding them in retrieved documents,
yet it quietly assumes that those documents are trustworthy in the first place. Even a
system that cites its sources perfectly can be wrong if the sources are of poor
quality, because the model can only reason over what it is given @gyongyi2004. This makes the trustworthiness
of the source collection a concern that comes before retrieval and not after it. If
unreliable documents sit in the knowledge base, they can be retrieved and passed to the
model just as easily as good ones.

A long line of work treats trust not as a property judged for each document in
isolation, but as something that flows through a graph of connected documents. The
classic example is TrustRank, which starts from a small seed of known good pages and
propagates trust across the link graph of the web. Pages linked to trusted ones are
treated as more trustworthy, while likely spam is pushed down @gyongyi2004. TrustRank
builds directly on PageRank and applies the same propagation idea to reliability
instead of popularity.

More recent work has brought this propagation idea into RAG document collections.
ClaimTrust adapts a PageRank-style algorithm to score documents by whether the factual
claims they contain support or contradict one another. Documents corroborated by others
gain trust, while isolated or contradicted ones lose it @qian2025. RAGRank follows a
similar direction but focuses on the placement in the pipeline. It computes a
PageRank-based authority score for each document and uses it together with the
retrieval similarity score as a second filtering step, so that low-credibility
documents are less likely to reach the model @jia2025. Both show that graph-based trust
propagation can rank source documents by reliability without heavy manual labelling.

Trust is rarely captured by a single signal. Work in high-stakes technical domains
argues that document credibility is best assessed from several complementary
perspectives at once. These are structural trust from how documents connect in a graph,
source trust from the author and institution behind a document, and content trust from
intrinsic quality indicators @yu2025trust. Combining these signals gives a more stable
picture than graph structure alone, especially when the graph is sparse or a document
has few connections.

Taken together, these methods show that source trust can be estimated automatically and
propagated through a document graph. Most existing work, however, is built around web
spam or news and claim verification, and treats trust either as pure graph propagation
or as a single-source judgement. Less attention has been paid to computing a
document-level trust score before retrieval that combines a metadata-based prior with
graph propagation, and to doing so for a real enterprise knowledge base. This is the
setting this thesis addresses.

== Evaluation and Observability of RAG Systems

Once a system retrieves and answers, its quality has to be measured. Evaluating a RAG
system is not as simple as checking whether the final answer is correct, because a RAG
pipeline has two separate parts that can each fail on their own. The retriever might
pull the wrong documents, or the generator might write an unsupported answer even when
the right documents were retrieved. For this reason most research evaluates the two
parts separately. The retrieval step is judged on whether it found the right content,
and the generation step is judged on whether the answer is faithful to that content and
relevant to the question @yu2025eval. This separation makes it much easier to see where
a problem comes from.

On the retrieval side, a few standard metrics are commonly used. Hit\@k checks whether
at least one correct chunk appears in the top k results. Recall\@k goes further and
measures how many of the existing correct chunks were found, which shows how much was
missed. Mean Reciprocal Rank (MRR) looks at where the first correct chunk lands in the
ranked list, so a system that places the right answer near the top scores higher than
one that buries it lower down @manning2008. Together these show whether something
correct was found at all, how much was found, and how well it was ranked.

On the generation side, the focus shifts to the quality of the answer itself, mainly
whether it is faithful to the retrieved content and whether it addresses the question.
Checking this by hand for every answer does not scale, so frameworks have been built to
automate it. RAGAS is a widely used framework that scores a RAG system on a fixed set
of metrics such as faithfulness, answer relevance, and context precision and recall. It
uses an LLM to compute them and needs only a small amount of ground truth @es2024. This
makes it practical to evaluate many questions quickly and consistently.

Some parts of answer quality are hard to capture with fixed formulas, for example
whether an answer sounds natural or fully matches the intent behind a question. To
handle this, researchers use an LLM itself as the evaluator and prompt it to score a
response the way a human reviewer would. This approach, known as LLM-as-a-judge, agrees
with human preferences in more than 80% of cases when a strong LLM does the judging
@zheng2023. It is not perfect and can carry biases, such as favouring longer answers or
being influenced by the order in which responses are shown, but it remains a practical
way to evaluate answer quality at scale.

Metrics show how well a system performs, but not what happened inside it when
something goes wrong. As RAG pipelines grow more complex, checking whether the final
answer is right is no longer enough. Research has argued for a shift away from
black-box testing toward deep system observability, which tracks what happens at every
internal step, including retrieval paths, token costs, latency and errors
@moshkovich2025 @kreuzberger2023. Because language models are non-deterministic, the
same question can take a different internal path on two runs, which makes standard
debugging tools poorly suited to finding the root cause of a problem. Keeping a
detailed record of every action as traces and spans, from the initial retrieval search
through to the final reranking, addresses this. Structured trace logs have been shown
to let developers diagnose root causes, find where the system slows down, and use that
evidence to reduce cost and improve the overall design @moshkovich2025.

== Research Gap

Across these three areas a clear pattern emerges. Retrieval research has moved from
single dense vector search toward hybrid and graph-based methods, but most of this work
is tested on general or multi-hop benchmarks and not on a real, single-domain
enterprise knowledge base, and few systems combine semantic and structural graph
signals. Trust research has shown that reliability can be propagated through a document
graph instead of being judged document by document, but this idea has mainly been
applied to web content and claim verification, and rarely to a document-level score
computed before retrieval in an enterprise setting. Evaluation research provides solid
metrics for judging retrieval and generation separately, and observability tooling
makes it possible to see why a pipeline produced a given answer, but these tools are
rarely applied together to compare a baseline system against an improved one in a
systematic way.

These three gaps are not separate problems. A retrieval system that finds more relevant
content is only useful if the sources behind that content can also be trusted, and both
improvements can only be judged reliably with proper evaluation and observability in
place. This thesis addresses all three together. It extends the AVAILABLE learning
assistant with hybrid retrieval, an automated trust score, and a full evaluation and
observability setup, so that the three sub-questions introduced in the introduction can
be answered as one connected piece of work and not in isolation.
