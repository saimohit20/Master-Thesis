= Scope

This thesis focuses on the retrieval and trust components of the existing AVAILABLE
system. It does not build a new chatbot from scratch. The main aim is to improve the
underlying RAG pipeline by testing modern retrieval approaches and checking whether
they lead to measurable improvements over the baseline, AVAILABLE 1.0. The pipeline is
built with the LangChain framework#footnote[#link("https://www.langchain.com")]. A
hybrid retrieval method is implemented that combines vector search with graph-based
search on a Neo4j#footnote[#link("https://neo4j.com")] graph database. It is
complemented by a cross-encoder reranker and the Opik#footnote[#link("https://github.com/comet-ml/opik")]
observability tool. The results are compared against the baseline using the
RAGAS#footnote[#link("https://docs.ragas.io")] evaluation framework @es2024.

The second focus of this thesis is the design and implementation of an automated trust
scoring framework. Instead of the manual trust ratings used in the baseline, a
document-level trust score is computed directly from the documents and their metadata.
The framework is evaluated on the existing Bosch Rexroth training data to examine how
well the automated scores reflect the actual reliability of the sources.

Some parts of the overall system are intentionally left outside the scope of this
work. The multi-agent components, which are the question and answer mode, the guided
assistant and the interview feature, are not modified, since the work targets the RAG
pipeline and not the agent logic. This thesis also does not compare different large
language models and does not train any model on the training data. The base language
model is used as provided, and the work concentrates on the retrieval and trust layers
around it.
