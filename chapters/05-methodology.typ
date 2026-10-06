= Methodology

== System Overview and Architecture

AVAILABLE is a learning assistant built on the training material of the Bosch Rexroth
Academy. It supports several learning use cases, such as a guided assistant that
recommends training material based on the topic and level of a user, and a question and
answer mode that returns a direct answer to a question. These modes differ in how they
interact with the user, but they share the same backbone, a Retrieval-Augmented
Generation pipeline that searches the training corpus for relevant passages and then
uses a large language model to write an answer grounded in them. The project exists in
two generations. AVAILABLE 1.0 was developed by the Bosch team @dommermuth2025 and
serves as the baseline of this thesis. AVAILABLE 2.0 is the system developed in this
work, which extends the baseline. This section describes how AVAILABLE 2.0 is built and
uses the first version as the reference point against which the changes are explained.

In AVAILABLE 1.0, retrieval relies on semantic search alone. During preparation, the
training documents are converted to text, embedded and stored in a FAISS vector index.
At query time the question is embedded in the same way and matched against the index by
vector similarity. The closest passages are passed to GPT-4o, deployed on the Azure
infrastructure of Bosch, which writes the answer and cites the training material it
used. Document trust is handled manually. A training folder can contain an optional
trust file in which the responsible team marks a document as unchecked, trusted,
outdated or wrong. This flow is shown in @fig-available-1.

#figure(
  image("../figures/available1.0.png", width: 100%),
  caption: [AVAILABLE 1.0 architecture, with document preparation above and query handling below.],
) <fig-available-1>

The first version established the core idea and the interface of the system, but
feedback from the internal teams pointed to several limitations. The sources retrieved
for a question often did not match what was asked. Teams wanted to upload new training
material themselves instead of depending on the development team. They also asked for
visibility into the behaviour of the system in production, covering latency, cost,
errors and recent questions, and for a way to compare a baseline against an improved
system on defined metrics before any change goes live. A review of the system added one
further finding. The trust of a document depended entirely on a manual rating that most
documents never received. @tab-overview links each of these points to the part of
AVAILABLE 2.0 that addresses it.
// TODO: add the source of the team feedback (meeting, interviews or document) and cite it.

#figure(
  [
    #set text(size: 10pt)
    #table(
      columns: (1.1fr, 1.2fr, 1.5fr),
      align: left + top,
      inset: 6pt,
      [*Topic*], [*AVAILABLE 1.0*], [*AVAILABLE 2.0*],
      [Document intake], [Added manually by the development team],
        [Collected automatically from SharePoint sites],
      [Retrieval], [Semantic search in a FAISS index],
        [Hybrid search over a vector store and a knowledge graph],
      [Ranking], [Order by vector similarity],
        [Cross-encoder reranking with a trust boost],
      [Document trust], [Optional manual rating per folder],
        [Automated trust score for every document],
      [Monitoring], [Not available], [Tracing of every step with Opik],
      [Evaluation], [No systematic procedure],
        [Evaluation harness with retrieval and generation metrics],
    )
  ],
  caption: [Comparison of AVAILABLE 1.0 and AVAILABLE 2.0.],
) <tab-overview>

AVAILABLE 2.0 addresses these points through new components placed around the same
retrieval and generation core. The architecture is shown in @fig-available-2 and is
divided into three pipelines.

#figure(
  image("../figures/avaialable2.0.png", width: 100%),
  caption: [AVAILABLE 2.0 architecture with the data ingestion, retrieval and generation, and observability and evaluation pipelines.],
) <fig-available-2>

The data ingestion pipeline runs ahead of any query and produces everything the query
time flow depends on. Material is collected and cleaned from several SharePoint sites
into one organised data store, which removes the dependency on the development team for
adding new content. The cleaned material is split into chunks. These chunks are used to
build three stores at once, a vector database with dense and sparse representations for
semantic search, a knowledge graph that connects chunks through the structure of the
documents and through entities and relations extracted by an LLM, and a metadata store
holding the chunk text and document information. The graph is what allows related
content to be found when the wording of a question does not match the wording of a
passage. A trust score is also computed for each document at this stage, built from
document metadata and supporting evidence, and it replaces the manual rating.

The retrieval and generation pipeline handles a question at query time. The question is
searched against the vector store and the knowledge graph in parallel, and the two
result lists are merged by union into one candidate pool. A cross-encoder reranker then
scores this pool more precisely, and the trust score of each document is applied at this
step as a boost. More trustworthy documents move higher in the ranking, while less
trustworthy ones are not removed from the pool. The top passages are passed to the LLM,
which generates the final answer. The pipeline can run in vector, graph or hybrid mode,
which makes it possible to compare the retrieval approaches under identical conditions.
// CONFIRM: the Vector / Graph / Hybrid box in the figure is described here as retrieval modes.

The observability and evaluation pipeline sits beside the live flow. Every step of a
request is traced with Opik, which provides the visibility into latency, cost, errors
and recent questions that the teams asked for. An evaluation harness runs separately on
its own dataset of questions with ground truth, and scores retrieval and generation with
the metrics introduced in the theory chapter. This allows a baseline and an improved
version to be compared before a change reaches production. The components of the three
pipelines are described in detail in the sections that follow.

== Data Preparation and Cleaning

The quality of a Retrieval-Augmented Generation system depends heavily on the quality
of the data it retrieves from @lewis2020. No downstream method can recover information
that is missing at the source, out of date, or represented inconsistently. Gathering
this material and keeping it in a consistent and current form is therefore a
precondition for the retrieval methods that follow. The result is a structured corpus
on which the retrieval components build.

=== Data Source

The corpus used in this thesis consists of 247 documents drawn from three topics,
Grownfield, Digital Transformation and Hydraulics, and it spans both German and English
material. Hydraulics covers engineering training on hydraulic systems, from fundamentals
such as pressure and flow through to components and troubleshooting. Digital
Transformation covers strategic and conceptual training on Industry 4.0 and the
digitalisation of manufacturing. Grownfield, the largest topic by far, covers hands-on
process training tied to a company-wide migration of business processes to a new SAP
system. The distribution of documents across topics is shown in @tab-corpus-topics, and
the distribution across file formats is shown in @tab-corpus-formats.

#figure(
  table(
    columns: (2fr, 1fr),
    align: (left, right),
    [*Topic*], [*Documents*],
    [Grownfield], [TODO],
    [Digital Transformation], [TODO],
    [Hydraulics], [TODO],
    [*Total*], [*247*],
  ),
  caption: [Distribution of the corpus across topics.],
) <tab-corpus-topics>
// TODO: fill the numbers and add the difficulty level columns from your Table 3.

#figure(
  table(
    columns: (2fr, 1fr),
    align: (left, right),
    [*File format*], [*Documents*],
    [PowerPoint], [TODO],
    [PDF], [TODO],
    [Video], [TODO],
    [Other], [TODO],
  ),
  caption: [Distribution of the corpus across file formats.],
) <tab-corpus-formats>
// TODO: fill the numbers from your Table 4.

=== Data Processing

The data preparation follows a medallion architecture#footnote[The medallion architecture
is a data design pattern from the data lakehouse paradigm, in which data is refined
across successive bronze, silver and gold layers of increasing quality and structure.],
a staged design in which raw input is refined through successive layers of increasing
structure #text(fill: red)[\[CITE: Databricks medallion architecture\]]. Three layers are
used in this work. The Bronze layer gathers the raw files from SharePoint and keeps a
local copy synchronised with the source. The Silver layer reads each file and turns its
content into uniform, structured records in one common representation. The Gold layer
gathers these records into the chunk collection that the retrieval stage indexes.
@fig-medallion shows the full pipeline with the three layers marked.

#figure(
  image("../figures/medallion-pipeline.png", width: 100%),
  caption: [The data preparation pipeline, organised as a medallion architecture. Raw
  training files are collected from several SharePoint libraries into a synchronised
  local mirror (Bronze), extracted and standardised into uniform structured records using
  GPT-4o and Whisper (Silver), and assembled into per-training collections of chunks
  (Gold). The Gold chunks are the input to the retrieval stage, where they are embedded
  into a vector index and arranged into a knowledge graph.],
) <fig-medallion>

Separating the work into these layers keeps each concern in one place and makes the
pipeline easy to rebuild. Raw files are never altered, cleaning and format handling
happen only in the Silver layer, and only the Gold layer produces the artifacts used
downstream. Every step is incremental, so once the corpus has been built, later runs
process only the files that have changed.

=== Bronze Layer

The pipeline begins with the data as it already exists inside the company. Before any of
it can be summarised or indexed, the raw material has to be gathered from its original
locations and brought into a consistent state. This is the work of the Bronze layer.

The training material is stored in several SharePoint libraries and comes in different
formats. Most of these formats, such as PowerPoint decks, video recordings, PDFs and
Word documents, are readable as they are and need no special treatment. Two formats are
the exception, because they do not contain the document itself. Web shortcuts are links
to Docupedia#footnote[Docupedia is the internal enterprise wiki of Bosch, based on
Confluence.] pages, and Windows shortcuts are only pointers to a file stored elsewhere.
Both are handled during collection. Each web shortcut is exported to HTML so that the
page content is captured, and each Windows shortcut is resolved by finding the original
file from its path and downloading that file. Access to SharePoint for all of this is
handled through the Microsoft Graph API#footnote[Microsoft Graph is the unified REST API
through which applications access Microsoft 365 data, including SharePoint document
libraries. See #link("https://learn.microsoft.com/graph").].

Once the formats are handled, the files are sorted into a fixed hierarchy of topic, then
level, then training module. This order is the Bosch Rexroth standard, and it also
supports the later construction of the knowledge graph. The sorted files are then
uploaded to one consolidated SharePoint library, which from this point on serves as the
single source of record for the corpus. Downstream processing does not read from the
cloud directly. Instead, the consolidated library is mirrored to a local copy, because
reprocessing files locally is faster and avoids repeated downloads of a large library on
every run. The mirror is kept up to date incrementally. A small manifest records the
path of each file together with its entity tag, or eTag#footnote[An entity tag (eTag) is
an HTTP identifier that changes whenever a resource is modified, which allows efficient
change detection without downloading the file.], which SharePoint changes whenever a file
changes. On each run the manifest is compared against the library. New files are
downloaded, files that were removed in the cloud are deleted locally, and files whose
eTag is unchanged are skipped.

The result of the Bronze layer is a local mirror of every source file, still in its
original format, together with the manifest that keeps it aligned with the cloud. The
corpus is now complete and current, but it is still a set of raw files in many different
formats. Converting those files into clean and uniform text is where the Silver layer
takes over.

=== Silver Layer

The Bronze layer produces a complete local copy of the source files, but those files are
not yet usable for retrieval. The purpose of the Silver layer is to transform the
information contained in these files into a single, uniform textual form. This is the
most involved part of the data preparation, because each format stores its content in a
different way and needs its own method to recover it. It relies on two hosted models,
GPT-4o#footnote[GPT-4o is a multimodal large language model of OpenAI that accepts both
text and images.] for reading text and images and Whisper#footnote[Whisper is the
automatic speech recognition model of OpenAI @radford2023.] for transcribing speech,
both served through Azure OpenAI#footnote[Azure OpenAI Service provides access to OpenAI
models such as GPT-4o and Whisper hosted inside Microsoft Azure, which keeps the data
within the own cloud tenant of the organisation.].

Not every format is accepted. The formats that are processed are PowerPoint
presentations, PDF documents, recorded videos, exported web pages, Word documents,
spreadsheets and email exports. Any other format is skipped in this layer, and the names
of the skipped files are written to a separate text file rather than being dropped
silently. This record lets the developers review later what was left out and decide
whether a new format should be supported in future versions.

Presentations and PDF documents are handled through a common path. A presentation is
first converted into a paged document, so that slides and PDF pages can be treated in
the same way. Each page is then read on two levels. Its written text is taken directly
from the page, and the page is also rendered as an image and passed to GPT-4o, which
describes the visual content that plain text cannot capture, such as diagrams,
screenshots and figures #text(fill: red)[\[CITE: multimodal / visual document
understanding\]]. The pages are read in sequence, and the summary of the earlier pages is
given to the model as context for the next one, so that the description of a deck stays
consistent from page to page.

Recorded videos carry information in two channels at once, the spoken narration and the
slides shown on screen, and both are recovered. The audio track is separated from the
video and transcribed by Whisper, which also returns the time span of each spoken
segment. Long recordings are split into shorter parts before transcription and joined
again afterwards, with the timestamps adjusted so that they remain correct. In parallel,
the video is sampled at a fixed interval to capture the slide visible at each point, and
each captured slide is described by GPT-4o. The recording is then divided into segments,
and for every segment three parallel views are kept, the spoken transcript, the visual
description of the slide, and a consolidated account that combines the two. Every
segment keeps the start and end time it covers, so that a later answer can be traced
back to the exact moment in the recording.

The remaining formats contain mostly text and need less interpretation. Exported web
pages, which originate from Docupedia, are first converted into a lightweight markup
form#footnote[Markdown is a lightweight markup language that preserves structure such as
headings, lists and tables in plain text.] that preserves their tables, headings and
lists, so that the structure of the page is not lost. Word documents, spreadsheets and
email exports are read directly, together with any attachments. In every case the
recovered text is then passed to GPT-4o for the same treatment as the text taken from a
slide or a video.

Across all of these formats, the model is never asked for free text. Each call is
constrained to return a fixed JSON structure with a short title and a description of the
content, and this is the step that turns unstructured material into structured records.
The instruction also asks for the output in English, which has the useful effect of
normalising the German and the English material into one language
#text(fill: red)[\[CITE: cross-lingual retrieval\]]. The full prompts are given in the
appendix. The model is called with deterministic settings, so that the output is as
reproducible as possible.

Every record is stored together with a set of metadata, which is a small structured
description that sits alongside the text of the record. Its purpose is to let the later
stages work with a record without reopening the original file or having to guess where
the record came from.

This metadata falls into a few kinds. The first identifies the record and its origin. It
gives each record a unique identifier and states which file it was taken from, which
page or which video segment it represents, and, for video, the exact start and end time
it covers. This makes every record traceable, so that an answer can later point back to
the precise slide or moment it came from. The second kind places the record in the
training hierarchy by recording its topic, its level and its training module. The third
kind is taken from SharePoint through the Microsoft Graph API and describes the document
at its source, including the author, the creation and last modification dates, the
original file type and the web address. This last kind is what the trust score, described
in the trust scoring section, later builds on.

The metadata also records how each record connects to the records around it. Each record
points up to its parent, the larger summary it belongs to, and each summary points down
to its children, the smaller records beneath it. Records that follow one another also
point to their previous and next neighbour, so that the reading order of a document is
preserved and a slide still knows which slide came before it and which comes after.
Finally, records that capture the same content in different ways, such as the transcript,
the slide and the combined view of one video segment, are linked to one another as
related records.

These links matter because they turn a flat collection of records into a connected
structure. During retrieval the system can begin at one relevant record and then move
upward to its parent for broader context, downward to its children for more detail, or
sideways to its neighbours and related records for continuity and for the other views of
the same content. The same links also form the backbone of the knowledge graph
@edge2024, where the parent, child and related relationships become the edges that join
documents, sections and chunks.

By the end of the Silver layer, the corpus no longer exists as slides, videos and web
pages. It exists as uniform, structured records, each written in English and carrying a
full description of where it came from. What these records still lack is a form suited
to search, since a whole document is too large to return as a single result. Turning them
into a clean collection of chunks, ready to be indexed for retrieval, is the task of the
Gold layer.

=== Gold Layer

The Silver layer produced clean, uniform records, but they are still spread across the
pipeline one file at a time. The aim of the Gold layer is to bring these records
together into their final form, so that each training becomes a single, tidy package that
the retrieval system can pick up and use. This is the last step of the data preparation,
and once it is done the corpus is ready to be searched.

==== Chunking

The content of each document is divided into small pieces called chunks. The split
follows the natural structure of the document rather than a fixed length, so each chunk
is a part that already stands on its own @zhong2024. A slide deck or a PDF is divided
page by page, so that every slide or page becomes one chunk. A video is divided along
time, so that each timed segment of the recording becomes one chunk. A web page or an
email becomes a single chunk, since it has no page structure to split on, and it is
broken down further only when it is embedded for search#footnote[LangChain is an
open-source framework for building applications with large language models. Its text
splitter utilities divide long text into overlapping character-based chunks at embedding
time, as described in the retrieval implementation section.]. Splitting by structure in
this way keeps each chunk centred on a single idea, which is more useful for retrieval
than cutting the text into equal blocks that might break in the middle of a point.

Each chunk holds three things together, the summary that GPT-4o produced for that piece,
the original text it was summarised from, and the metadata described in the Silver
layer, such as its identifier, its source, its position and its links. Because a chunk
carries its own metadata, it can be understood and traced on its own, without opening the
document it came from.

Every document produces two files at this stage, a JSON file that holds its chunks and a
text file that holds its summary. The chunks of all the documents that belong to the same
training are then collected into one JSON file for that training, so a training is no
longer a set of separate documents but a single ordered collection of chunks.

An overview of each training is also generated by GPT-4o. The individual document
summaries are passed to GPT-4o, which condenses them into a single description of the
training as a whole.

The result of the Gold layer, and of the data preparation as a whole, is a clean
collection of chunks. Each chunk is written in English and carries its full metadata and
its links to the chunks around it. The corpus is now ready to be made searchable. In the
retrieval stage, described in the next section, these chunks are embedded into a vector
index#footnote[The vector index is a Qdrant store of embeddings produced by the BGE-M3
model @chen2024.] and arranged into a knowledge graph, the two representations over which
the system retrieves.

== Retrieval Implementation

The data preparation ends with a clean collection of chunks, but chunks on their own
cannot answer a question. For each query the system has to find the few chunks that
matter and put the best of them in front of the language model. This is the task of
retrieval. Retrieval here looks at the corpus through two eyes. One eye searches by
meaning over a vector index, and the other looks through the knowledge graph. Each eye
finds things the other can miss, so their results are combined and then reordered before
they reach the model.

This section describes how each chunk is turned into a vector and kept in a vector
database. It then looks at how the two eyes search, the vector eye on its own and the
graph eye on its own, and how their two views are joined into one through a fusion step.
It ends with the reranker, which puts the final chunks in the best order before they
reach the model.

=== Embedding

The baseline embedded each chunk with a single small, English-only dense model,
BAAI/bge-small-en-v1.5, and stored the result as one dense vector. Two properties of the
corpus made this a bottleneck. First, the material is bilingual, and an English-only
model represents the German content poorly. Second, industrial training is full of exact
identifiers such as process codes and machine numbers. A purely dense vector blurs two
similar looking codes and can return the wrong document for an exact code query. Both
weaknesses work against the reliability the assistant is meant to improve.

The model was therefore replaced with BGE-M3#footnote[BGE-M3 (BAAI General Embedding) is
a multilingual model that produces dense, sparse and multi-vector representations in one
pass.] @chen2024. BGE-M3 is multilingual, so it handles the German and the English
material in one model. It produces a dense vector for meaning together with a sparse
vector for exact words in a single pass, so codes are matched on the sparse side while
meaning is matched on the dense side. It is also a larger model with a longer input
limit, which gives stronger representations of the longer enterprise documents. Producing
both vectors from one model, instead of adding a separate keyword index beside the dense
one, keeps the pipeline simple to scale. BGE-M3 is built on a multilingual transformer
encoder#footnote[BGE-M3 is built on the XLM-RoBERTa architecture, a multilingual
transformer encoder.], has about 570 million parameters, produces a dense vector of 1024
dimensions, and accepts up to 8192 tokens. It is downloaded from the Hugging Face Hub and
run locally, so the training data never leaves the machine to be embedded, unlike the
GPT-4o calls in the Silver layer. Dense vectors are compared by cosine similarity and
sparse vectors by the weighted overlap of their terms. The pipeline is implemented in
Python with LangChain.
// TODO: footnote 3 of your draft (MTEB leaderboard) had no anchor in the text. Add it where you meant it.

Two smaller measures make the representation fairer to short documents. Before a chunk
is embedded, the stored JSON is cleaned back into plain prose and a short identity line
with the code, title and level of the document is placed in front of it, so the code
becomes part of the embedded text. A single stronger vector is also built for each
document from its code, title and description, so that short overview documents are not
lost to longer ones that contribute many more chunks. @tab-representation summarises the
change from the baseline.

#figure(
  [
    #set text(size: 10pt)
    #table(
      columns: (1.2fr, 1.4fr, 1.6fr),
      align: left + top,
      inset: 6pt,
      [*Aspect*], [*Baseline*], [*AVAILABLE 2.0*],
      [Embedding model], [BAAI/bge-small-en-v1.5], [BGE-M3],
      [Language coverage], [English only], [Multilingual, German and English],
      [Vectors per chunk], [One dense vector], [One dense and one sparse vector],
      [Exact code matching], [Blurred by the dense vector], [Handled by the sparse vector],
      [Vector store], [FAISS, a file loaded into memory], [Qdrant, a database service on disk],
    )
  ],
  caption: [Baseline and enhanced retrieval representation.],
) <tab-representation>

=== Vector Database

The baseline stored its vectors in FAISS, a similarity search library that indexes dense
vectors only. FAISS could no longer hold the full representation, since adding the
keyword signal would have meant running and synchronising a second, separate index
beside it. FAISS is also just a file that the program loads into memory, and not a
database that runs on its own, which makes it hard to serve a large enterprise knowledge
base.

For these reasons the vector store was moved to Qdrant#footnote[Qdrant is an open source
vector database. See #link("https://qdrant.tech").], which supports hybrid search
directly. Qdrant keeps the dense and the sparse vector of every chunk in one place and
combines them at search time, so exact code matching and meaning based matching stay
together. It runs locally in a Docker container as its own service, saves the index on
disk, and scales more easily as the corpus grows. Inside Qdrant the dense vectors are
kept in memory and compared by cosine similarity, while the sparse vectors are kept on
disk to save memory.

Each chunk is also split into smaller pieces of about a thousand characters with a little
overlap, and only these pieces are stored and searched, because a short piece is easier
to match well. The full chunk is kept aside, and when one of its pieces is matched, the
whole chunk is returned. The search stays precise, and the model still receives the full
context.

=== Vector Eye

The first eye searches the vector database. When a question comes in, it is embedded with
the same BGE-M3 model into a dense and a sparse vector, and both are sent to Qdrant.
Qdrant runs two searches at once, one that matches the question by meaning through the
dense vectors and one that matches it by exact words through the sparse vectors. This
hybrid search is the main change from the baseline, which searched by meaning alone and
often missed an exact code or machine number named in the question.

The two searches produce two ranked lists, which Qdrant merges into one with reciprocal
rank fusion @cormack2009. This method merges by the position of a chunk in each list and
not by its score. The dense and sparse scores sit on different scales and therefore never
have to be compared directly, and no weight has to be set by hand between meaning and
exact words.

From the merged list the vector eye keeps its top ten chunks and passes them on. Ten is a
moderate depth that balances recall against the noise and the lost in the middle effect
discussed in the literature review, and it is not a value tuned on the evaluation set.
These chunks are only the view of one eye, and they are combined with the graph eye
before the final ordering.

=== Graph Eye

The vector eye is strong at finding chunks that look like the question, but it has a
blind spot. It looks at each chunk on its own and cannot connect pieces of information
that sit in different documents. Take the question "In which SAP system is the outbound
delivery created?". The sales order document mentions the outbound delivery but not the
system, so it answers the question only in part. The system is explained in a separate
warehouse document that shares few words with the question, and the vector eye cannot
reach it. The graph eye addresses this by treating the corpus as a knowledge graph, in
which chunks and the things they mention are linked. In that graph the two chunks are
joined through the shared item outbound delivery, so the second chunk, the one that holds
the answer, can still be found. The baseline had no such component. The graph eye is a
new addition of this work, and it follows the line of graph-based retrieval methods in
the literature @edge2024 @sarthi2024.

==== Graph Construction

The graph is built in two layers. The first layer fixes the skeleton from the folder
hierarchy, and the second adds meaning on top of that skeleton. @fig-kg-schema shows the
schema.

#figure(
  image("../figures/knowledge-graph-schema.png", width: 85%),
  caption: [Schema of the knowledge graph with its structural layer and its semantic
  layer. The table lists the edge weights used during traversal.],
) <fig-kg-schema>

The structural layer is built directly from the folder hierarchy and from the links
already stored with each chunk. Topics, subtopics, trainings, documents and chunks become
nodes, joined by `contains` and `part_of` edges, so that the graph knows that a chunk
belongs to a document and a document to a training. A deterministic build was chosen over
inferring this structure with a model, because the hierarchy is already recorded exactly
in the data, and a model would add cost and errors with nothing to gain. This layer is
cheap and exact, and it gives every later step a reliable backbone on which weight can
pool inside the correct document or training.

Structure alone only links chunks that already sit close together. It cannot join two
chunks in different documents that discuss the same thing, which is the very gap the graph
eye is meant to close. The semantic layer adds this. The entities that the chunks talk
about, and the relations between them, are extracted from the text. The chunks are
grouped into small overlapping batches and passed to a large language model, GPT-4o by
default. For each batch the model returns the entities it mentions and the typed relations
between them, for example requires or precedes, each tagged with a confidence and the
chunk it came from. An extraction prompt fixes what is extracted and how. It requests
strict JSON, and its rules keep the output grounded. Only information explicitly supported
by the chunks may be used, entity labels must be short and canonical, confidences must lie
between 0 and 1, and an empty result must be returned when the model is unsure. The full
prompt is given in the appendix. An LLM was chosen over a rule-based or trained extractor
because the vocabulary is domain specific and unlabelled, which makes a supervised tagger
impractical.

The extracted entities are then merged. Entities that refer to the same thing become one
node, and rarely seen ones are dropped. Each surviving entity is given a specificity
weight, its inverse document frequency,

$ "IDF"(e) = log (N / "df"(e)) $

where $N$ is the total number of chunks and $"df"(e)$ is the number of chunks that mention
entity $e$ @sparckjones1972. An entity that appears almost everywhere therefore counts for
little, while a specific one counts for a lot. Finally the merged entities are written
back into the graph as entity nodes. Each is linked to every chunk that mentions it by a
`mentions` edge, and to other entities by typed relation edges. Each topic ends with its
own set of nodes and edges. This is what allows the two chunks in the earlier example to
be joined through the shared entity outbound delivery, even though they share few words.

==== Graph Traversal

Retrieval on the graph works differently from vector search. Vector search scores each
chunk on its own by how close its wording is to the query and returns the closest ones. It
never looks at how chunks connect. Graph traversal starts instead from the concepts the
query is about. The query is matched to entities in the graph, and relevance then moves
along the edges to the chunks those entities link to. A chunk can be reached even when it
shares few words with the query, as long as the graph joins it to a matched concept.
Retrieval this way follows meaning and structure, and not surface wording.

Two engines can traverse the graph, and a mode switch picks which one runs. Both start
the same way and end the same way. Each matches the query to a few seed entities in the
entity index, and each returns a ranked list of chunks with scores to the fusion step.
They differ only in how relevance spreads from the seeds to the chunks. Both return the
same result object, so the fusion step and the reranker do not change when the engine is
switched. @fig-seeds shows the shared seed generation and the difference between the two
engines on a small example.

#figure(
  image("../figures/shared-seed-generation.png", width: 100%),
  caption: [Shared seed generation for both graph engines, with the entity hop on the left
  and Personalized PageRank on the right. Circles are entities, squares are chunks, and the
  numbers are the weights that reach each node.],
) <fig-seeds>

Seed weight is set the same way in both engines. Each seed entity is weighted by its
confidence signal multiplied by its IDF specificity, so that a generic entity that appears
almost everywhere counts for little @gutierrez2024.

==== Entity Hop

The entity hop matches the question to the concepts it names and then steps from those
concepts to the chunks that mention them. It runs alongside the vector eye on every query
and works well when the answer sits in chunks that name the concepts of the question
directly.

When a question comes in, it is first compared against every entity in the graph, using a
small vector index built only for entities. The closest matches become the seeds. Seeds
are the concepts the question is about, and they are the only points the walk can start
from, so this first match already decides how far the search can reach.

Not every seed deserves the same trust, so each one is given a weight. Two things set it.
The first is the confidence of the match, taken from the semantic similarity, from a fused
score that also rewards exact word matches, or from whichever of the two is higher, since
either route finding the entity is reason enough to trust it. The second is how specific
the entity is, measured by the IDF defined in the graph construction. The two parts are
multiplied into one seed weight,

$ "weight"(e) = "signal"(e) dot.op "IDF"(e) $

so that an entity that is both a strong match and rare in the corpus carries the most
weight @gutierrez2024. Weak matches below a floor are removed first, and the number of
seeds is capped, so the walk never starts from a long tail of loosely related concepts.

Sometimes nothing in the question matches the graph well enough. When every match falls
below the floor, the engine returns nothing instead of guessing. This is deliberate. The
graph result is later merged with the vector result, so an empty graph answer leaves the
result of the vector eye in place and does not weaken it with a poor match.

One more check happens before the walk spreads out. Each entity in the graph carries a
topic label. Because some terms show up under more than one topic, a matched entity can
belong to a topic that has nothing to do with the question. To handle this, the seed
weights are summed per topic, and only the topic with the most weight, together with any
topic close behind it, is kept. An off topic entity can then no longer pull the search
into the wrong part of the corpus.

The walk now moves outward from the surviving seeds. Each seed steps across its `mentions`
edges to every chunk that names it and passes its weight on to that chunk. A chunk named
by several seeds collects weight from all of them,

$ "raw"(c) = sum_(e in S(c)) "weight"(e) $

where $S(c)$ is the set of kept seeds that mention chunk $c$. The walk does not have to
stop here. It can go further, from a chunk to its own entities and on to more chunks, but
two rules keep this in check. The weight shrinks at each extra step by a decay factor $d$
between 0 and 1, so a chunk reached at hop $h$ contributes only
$"weight"(e) dot.op d^(h-1)$, much less than a chunk right next to a seed. Entities linked
to a very large number of chunks are also skipped in these later hops, since such a hub
connects to almost everything and would spread weight without adding real signal. By
default the walk stays at a single hop.

Once every chunk has its raw score, two adjustments are made. The first stops long chunks
from winning just by size. A chunk that mentions many entities has more chances to pick up
weight, so its score is divided by the square root of the number of entities it holds,

$ "norm"(c) = "raw"(c) / sqrt(|E(c)|) $

where $|E(c)|$ is the number of entities the chunk mentions. The second adjustment gives a
chunk a small boost when the best chunk in its own document already scored highly,

$ "score"(c) = "norm"(c) dot.op (1 + beta_d dot.op "prior"(d_c)) $

$ "prior"(d_c) = (max_(c' in d_c) "norm"(c')) / (max_d max_(c' in d) "norm"(c')) $

where $d_c$ is the document that holds chunk $c$ and $beta_d$ sets how strong the boost is.
The prior compares the best chunk in that document against the best chunk in the whole
corpus, so it always lies between 0 and 1. A chunk is therefore judged partly on its own
strength and partly on the strength of its document.

Finally, chunks that fall too far below the top score are dropped, no single document is
allowed to take too many places, and only the top $k$ chunks are kept. A smaller $k$ is
used when the seed confidence was low, so that a weak match cannot fill the result with
noise.

==== Personalized PageRank

The entity hop can take more than one step, but it never looks at how the whole graph is
connected. It adds up whatever weight lands on each chunk within a few jumps of the seeds
and stops. A chunk that is only loosely reachable can still score well because a short
path happens to touch it, while a chunk that is well connected to the question through
many small paths can be missed.

PageRank was introduced to rank web pages by their links and not only by the words they
held. A page counted as important if many pages linked to it, and more so if those pages
were important themselves. Importance came from how the whole web pointed to a page and
not from the page alone @page1999. Plain PageRank, however, gives the same ranking for
every user. Retrieval needs something narrower. It does not need to know which chunk is
important in general, but which chunk is important for this question. Personalized
PageRank does exactly that. It lets importance flow across the graph in the same way but
keeps pulling it back toward a chosen starting point, and in this work that starting point
is the set of concepts the question is about @haveliwala2002 @gutierrez2024.

When a question comes in, the engine first has to decide where the weight should start. It
looks up the concepts of the question in the entity index in the same way as the entity
hop, and these become the seeds. Two small checks keep the seeds clean. Entities whose
match is too weak are left out, although if none are strong enough the best few are kept
anyway, so that the walk always has somewhere to begin. Entities that show up in far too
many chunks are dropped, since a concept that appears everywhere says little about this
one question. What remains is merged, so that different spellings of the same concept fold
into one seed, and that seed keeps the weight of its strongest version instead of adding
them up. Each seed carries the same signal and IDF weight as before, so a strong and
specific concept starts with more weight than a weak or generic one.

The seeds do not have to come from the graph alone. The best chunks of the vector eye can
be added as extra starting points, weighted by their search score, so that the walk begins
partly from the strong vector signal without the two legs fully merging. By default these
chunk seeds take a fifth of the starting weight and the entity seeds take the rest. All of
this is gathered into one starting vector $e$ across the nodes of the graph, scaled so that
it adds up to one,

$ sum_i e_i = 1, quad e_i >= 0 $

This vector is where the walk keeps returning to. If none of the seeds land in the graph of
a particular topic, that topic is skipped. Now the weight begins to flow. From the seeds it
spreads out across the graph step by step, and at each step a part of it is pulled back to
the seeds, so that the walk never drifts too far from what the question was about,

$ pi = alpha dot.op S dot.op pi + (1 - alpha) dot.op e $

Here $pi$ is the weight that has settled on each node and $alpha$ decides how far the
weight may wander before it is pulled back. A higher $alpha$ lets it travel further across
the graph, a lower one keeps it near the seeds, and the value used here is 0.5. The flow is
repeated until the weights barely change from one round to the next.

As the weight flows, it does not treat every connection the same, and the strength of an
edge depends on its type. A `mentions` edge, which joins a chunk to a concept it talks
about, is the strongest signal and carries full weight. A relation between two concepts
carries a little less, and less again when the model was unsure about that relation. A link
between neighbouring chunks carries less still, and the structural links of the folder
hierarchy carry the least, just enough to keep weight pooling inside the right document. The
strength of a single edge between nodes $i$ and $j$ is

$ A_(i j) = cases(
  1.0 quad "for a mentions edge",
  0.8 dot.op "conf" quad "for a typed relation between entities",
  0.5 quad "for a related to edge between chunks",
  0.3 quad "for a hierarchy edge"
) $
// CONFIRM: the confidence scaling of typed relations is my reading of your draft. Adjust if the code differs.

where $"conf"$ is the confidence the model gave to the relation. The flow needs one more
rule, which says how a node shares its weight with its neighbours. A node passes on all the
weight it holds, split across its edges in proportion to their strength. This is captured
by taking the edge weights in the matrix $A$ and normalising each column,

$ S = A D^(-1), quad D_(j j) = sum_i A_(i j) $

so that every column adds up to one. The effect is quiet but important. A node with only a
few edges hands each neighbour a healthy share, while a node connected to almost everything
splits its weight so thinly that each neighbour barely feels it. A generic, over-connected
node therefore cannot take over the walk, in the same way as IDF stops common entities from
dominating the seeds.

When the flow settles, every node holds some amount of weight, and the chunks that
collected the most are the ones best connected to the question. Each topic was walked on its
own graph, so the results are then brought together according to how strongly the question
seeded each topic. A topic that drew more seed weight counts for more, the weight of each
chunk is scaled by the share of its topic, and a chunk that appears under more than one
topic keeps its highest value,

$ "score"(c) = max_t pi_t (c) dot.op "share"_t, quad "share"_t = "raw"_t / (sum_(t') "raw"_(t')) $

Only the chunks are read out for the final list, although the documents also collect weight
along the way, and the strongest of them are shown as recommended reading.

Finally the list is trimmed in the same way as in the entity hop, so that the rest of the
system sees one consistent kind of result. Chunks far below the top score are dropped, no
single document is allowed to take too many places, and the top $k$ are kept, fewer when the
seeds were weak to begin with. Because the weight moves through the whole graph at once
instead of in fixed jumps, this engine can settle on a chunk several relations away from any
seed, the case that the entity hop keeps missing. In the example of @fig-seeds the entity hop
gives no weight to chunk 4 and chunk 5, while Personalized PageRank reaches both through the
related to edge and through the second entity.

=== Hybrid Retrieval

Hybrid retrieval combines the vector eye and the graph eye. The vector eye is strong on
semantic meaning, and the graph eye is strong on connections through shared concepts. The
hybrid step brings their two views together. It merges their two ranked lists into one pool,
orders that pool by how well each chunk answers the question, and passes the best chunks on
to the generation step. @fig-two-eye shows the flow.

#figure(
  image("../figures/two-eye-retrieval-flow.png", width: 55%),
  caption: [The two eye retrieval flow from the two legs to the final top-k chunks.],
) <fig-two-eye>

==== Fusion

Both legs run, and their chunk lists are merged into one candidate pool by a union. The
chunks are taken one from the vector eye, then one from the graph eye, and a chunk found by
both legs appears only once. A union is used because neither leg can bury the other this way,
which is the risk when one list is longer or trusted more than the other. Writing the vector
list as $V = (v_1, v_2, dots)$ and the graph list as $G = (g_1, g_2, dots)$, the pool is

$ "pool" = "dedup"(v_1, g_1, v_2, g_2, v_3, g_3, dots) $

where $"dedup"$ keeps the first appearance of each chunk. No score is attached yet. This
order only decides which chunks make the shortlist, and the reranker sets the real order
next.

==== Reranking

The shortlisted chunks are re-scored by a cross-encoder model
#text(fill: red)[\[CITE: BAAI/bge-reranker-v2-m3\]]. The first stage of retrieval embeds the
question and each passage separately, which is fast but only rough. The cross-encoder reads
the question and one chunk together and judges how well that chunk answers the question
@nogueira2019. This is much more precise, and it is affordable because it runs only over the
small pool and not over the whole corpus.

The last part folds in trust and cuts the list. Each reranked score is adjusted by the trust
of the document a passage comes from, as described in the trust scoring section, so that
chunks from more trustworthy documents move up,

$ "final" = "rerank" dot.op (1 + beta_t dot.op "trust") $

where $beta_t$ sets how strongly trust influences the order. The pool is then sorted, the top
chunks are kept and sent to the generation step, and the unique documents behind them are
shown to the user as recommended reading. The two eye combination and the cross-encoder are
both new to this work. The baseline used a single vector leg, with no fusion and no
reranking.

== Trust Scoring Implementation

Retrieval and reranking bring back the passages that are most relevant to a question, but
relevance is not the same as reliability. Two documents can both match a question while
differing in how far they can be trusted. One might be a current internal handbook, the
other an outdated draft written by someone unknown. Both look equally good to a search
that only cares about wording and concepts, so something more is needed to tell them
apart.

This matters because of how the knowledge base is used. It acts as a single shared source
that many internal projects draw from, and it keeps growing over time. As it grows, older
material goes out of date, training documents from unknown authors find their way in, and
unnecessary files pile up next to the good ones. Nothing in the baseline measures how
reliable a document is, or how well it fits with the rest of the material around it. The
trust score is added to fill this gap. It does not check whether the facts inside a
document are right or wrong. It estimates how reliable a document is from its content
quality, its metadata, and how well it lines up with the rest of the knowledge base. That
estimate is then folded into the reranking step, so that more reliable sources are
favoured.

The score is built from two parts. The first is a prior, which measures the quality of a
document on its own terms. The second is a support score, which measures how strongly
other trusted documents back the document up. The two are blended, with the prior kept in
charge,

$ "TrustScore" = 0.7 dot.op "prior" + 0.3 dot.op "support" $

so a document earns most of its score from its own quality and is then nudged up or down by
how well the rest of the corpus supports it. @fig-trust shows the full computation.

#figure(
  image("../figures/trust-score-computation.png", width: 80%),
  caption: [Computation of the trust score. The prior is built from four pillars, the
  support score spreads trust across a document graph, and the final score is stored once
  at ingestion and read back at query time.],
) <fig-trust>

=== The Prior

The prior measures what is known about a document on its own. It combines four pillars,
each a value between 0 and 1,

$ "prior" = 0.45 dot.op "content" + 0.25 dot.op "authority" + 0.15 dot.op "format" + 0.15 dot.op "freshness" $

and the weights add up to one, so the prior also lies between 0 and 1.

The content pillar carries the most weight, because it reflects how useful the document
actually is as training material. It is scored by a language model that reads the generated
summary of the document and not its raw text, since the summary is the cleaned form that the
pipeline has already produced. The model rates four things, the technical depth, how
complete the procedure is, how usable the steps are, and how focused the document stays.
These ratings are averaged into one content score. The full prompt used for this rating is
given in the appendix. Videos receive the full content score by policy. This follows a
decision of the company, since the videos are produced by their own experts, so their
content quality can be assumed to be high even though a text summary does not capture their
real worth.

The other three pillars come from metadata. The authority pillar rewards a known source. A
document created or edited by an internal account scores highest, one from an external
vendor scores lower, and one from an unknown author scores lowest.
// TODO: add the three authority values you use.
The format pillar prefers structured, text based documents over image only slides, simply
because the pipeline can read text but cannot read a picture of a slide.
// TODO: add the format values per file type.
The freshness pillar gives a small reward to recent edits. It decays slowly, with a half-life
of three years, down to a fixed floor, since an old document is not automatically a wrong
one,

$ "freshness" = max(f_min, 2^(-"age" slash 3)) $

where the age is measured in years and $f_min$ is the floor.
// TODO: add the value of the floor. CONFIRM that the decay in the code has this form.
A document with no date receives a middle value.

=== The Support Score

The quality of a document on its own is not the whole picture. A claim that many trusted
documents also make is more believable than one that stands completely alone, so the second
part measures this backing @gyongyi2004 @qian2025. To do this, a second graph is built, this
time with one node per document. Two documents are joined when they mention the same
entities, and each shared entity adds its inverse document frequency to the link, so that
sharing a specific concept counts far more than sharing a common word,

$ A_(i j) = sum_(e in E_i inter E_j) "IDF"(e) $

where $E_i$ is the set of entities mentioned in document $i$. Entities that are found in more
than half of the documents are dropped as too generic, and an entity that is found in only
one document is ignored, since it cannot connect anything.

Trust then flows across this document graph with the same Personalized PageRank method as in
the retrieval leg, but for a different purpose @haveliwala2002. In retrieval the walk started
from the entities of the query and ranked chunks. Here it starts from the metadata prior and
ranks whole documents. The prior seeds the walk, and trust spreads from reliable documents to
the ones that back them up,

$ t = alpha dot.op S dot.op t + (1 - alpha) dot.op p $

where $t$ is the trust on each document, $S$ is the document to document transition matrix
built from the shared entity links in the same way as before, $p$ is the metadata prior used
as the seed, and $alpha$ is the damping factor, set to 0.5. The result is scaled so that the
most supported document scores one,

$ "support"(d) = t_d / (max_j t_j) $

A document with no entities, such as a video without text, has nothing that connects it to
others, so it simply keeps its prior.

=== Limits of the Method and the Choice of Weights

This method is useful, but it rests on assumptions that do not always hold, and three limits
are worth stating plainly.

The first is that it rewards the majority, and agreement is not the same as truth. Trust
flows toward documents that overlap with many others. If several documents repeat the same
outdated or wrong fact, the walk lifts all of them together, while a correct document that
stands alone with few neighbours is left near its prior. For a corpus that is made partly of
drafts and vendor slides, assuming that the crowd is right is not safe.

The second is that the edges only measure co-mention and not agreement. An edge is built
whenever two documents share entities, but two documents that both mention the outbound
delivery might say opposite things about it. The walk cannot tell backing from
disagreement, so a document that repeats a claim and one that disputes it are treated the
same, as long as they share the entity. The graph therefore only shows that documents talk
about the same specifics, which is a rough stand-in for actually supporting each other.

The third is that the seed is the prior itself, so the support score is only partly
independent of the quality that it is meant to add to.

These limits are the reason why the prior is kept in charge. The support score is given a
weight of only 0.3 in the final blend, while the prior holds 0.7, so that corroboration can
nudge a score but never override the measured quality of a document. A document that never
entered the graph keeps its prior.

=== Use at Query Time

The whole trust score is computed once, when a document is ingested, and it is stored in the
metadata of the document. At query time it is read back during the reranking step, where the
score of each passage is multiplied by $(1 + beta_t dot.op "trust")$, so that passages from
more trusted documents rise in the final order. How the trust score is tested, and whether it
behaves as intended, is covered in the evaluation chapter.

== Evaluation

The previous sections set out how the system works, from retrieving chunks and writing an
answer to scoring how much each document can be trusted. Those sections explain what was
built and why each choice was made. This section describes how the performance of the system
is measured. Instead of reading a few answers and judging them by feel, a fixed set of
questions is run through the real pipeline and the results are scored, so that different
retrieval approaches and the two versions of the system can be compared on equal terms.

The evaluation is split into two parts. The first part measures retrieval quality and asks
whether the system finds the right document for a question. The second part measures
generation quality and asks whether the written answer is good. The trust score is handled
separately. It is judged neither on retrieval nor on answer quality, but on whether it is
accurate and whether it improves the system, so it has its own evaluation. The results of all
experiments are reported in the experiments and results chapter.

=== Evaluation Datasets

The questions used for evaluation come from two sources. The first is written by internal
experts, and the second is a synthetic set built for this work. The training material covers
three topics, which are Grownfield, the SAP S/4HANA training, Digital Transformation and
Hydraulics. To test the system against real needs, the teams behind these topics were asked
for questions that their own users would ask, each paired with the correct answer and the
document it should come from. The Digital Transformation team was not available during the
period of this thesis, so expert questions could be collected only for the other two topics.
The Grownfield team contributed 40 questions across the SAP modules, a mix of single document
and multi document cases, and the Hydraulics team contributed 59 questions drawn from its
training handbook. Every question carries a ground truth answer and a golden source document,
which is what allows both retrieval and generation to be scored against a known target.

These expert sets are trustworthy, but they are small. Ninety nine questions in total, with
none at all for Digital Transformation, are too few to tell reliably whether the system works
well or badly, and too few to break the results down by topic, question type or retrieval
approach. A larger and more balanced set was needed before any real conclusion could be
drawn.

Since the training material itself was available, a synthetic question set was built from it,
covering all three topics including the one without expert questions. The set is built one
document at a time. For each source document, a language model reads the cleaned content and
writes five self contained questions, one of each of five types, factual, conceptual,
procedural, application and summary, so that a single document produces a spread of
difficulty and not five near copies. The full prompt is given in the appendix. Each question
is paired with a ground truth answer and a few keywords, and the document it was generated
from is recorded as its golden source. Every generated question is checked for these required
fields before it is kept. This produced 1215 questions across the three topics, more than ten
times the size of the expert sets, spread evenly across the five question types. @tab-datasets
summarises both sources.

#figure(
  table(
    columns: (1.4fr, 1fr, 1fr, 1.2fr),
    align: (left, left, right, left),
    inset: 6pt,
    [*Source*], [*Topic*], [*Questions*], [*Ground truth*],
    [Expert], [Grownfield], [40], [Written by experts],
    [Expert], [Hydraulics], [59], [Written by experts],
    [Expert], [Digital Transformation], [0], [Not available],
    [Synthetic], [All three topics], [1215], [Generated by a language model],
  ),
  caption: [Overview of the two evaluation datasets.],
) <tab-datasets>
// TODO: add the synthetic question count per topic if you want a finer breakdown.

The two kinds of dataset play different roles. The expert questions give a small, human
authored check that is tied to real information needs, while the synthetic questions give the
scale and coverage needed to compare approaches with confidence. Because the synthetic answers
are themselves written by a language model, they are treated as a broad measure and not as a
perfect reference, and the expert sets remain the stricter test.

One more precaution is taken with the synthetic set. The model that generates the questions
and answers is not the same model that judges the answers later, since a language model tends
to rate its own output more favourably than a neutral judge would. This effect is known as
self preference bias, where an evaluator scores text it produced itself higher than equivalent
text from another source @panickssery2024. Using different models for generation and for
judging keeps this bias out of the results.
// TODO: name the model used to generate the questions and the model used as judge.

=== Retriever Evaluation

Retrieval is checked by whether the golden source document is found. For each question the
system returns a ranked list of sources, and this list is compared against the golden source
that the question is known to come from. Two things matter here. The first is whether the
golden source is found at all, and the second is how high it sits in the list. A correct
source near the top is more useful than the same source buried far down, so its position is
measured and not only its presence. Two metrics are used, Hit\@k and mean reciprocal rank,
both as defined in the theory chapter. Hit\@k is read at a few cutoffs. Hit\@1 is the strict
case where the golden source is ranked first, and Hit\@10 is the looser case where it lands
somewhere in the top ten. Together the two metrics show how often the right source is found
and how well it is ranked.

The evaluation runs in three stages. The first stage chooses the graph engine. The graph leg
can be walked in more than one way, so the best way is settled before the graph is compared
with anything else. Three engines are tested on the same seeds, so that only the traversal
differs and the comparison stays fair. The entity hop takes a single step from the concepts of
the query to the chunks that mention them. The multi entity hop repeats that step over several
hops and reaches further across the graph. Personalized PageRank lets weight flow through the
whole graph at once. Each engine is scored on the same questions. Because the graph leg feeds a reranker, which can reorder candidates but cannot recover a document that was never retrieved, the engine that reaches the most golden documents is fixed as the graph engine for the rest of the evaluation, and ranking quality at the top is a secondary criterion.

The second stage compares the retrieval legs. With the graph engine fixed, the three legs are
compared under the same conditions. The vector leg retrieves by wording, the graph leg by
connected concepts, and the hybrid leg fuses the two. This stage shows whether adding the
graph to the vector leg helps the system find the right source, and whether fusing the two
beats either one alone. The leg that retrieves best is taken as the retrieval setup of
AVAILABLE 2.0.

The third stage compares the two versions of the system on the same questions. AVAILABLE 1.0
retrieves with vector search alone, while AVAILABLE 2.0 uses the retrieval setup chosen in the
previous stage together with fusion and reranking. This final test shows what the changes of
the second version achieve for retrieval as a whole.

=== Generator Evaluation

Retrieval shows whether the right source was found. Generation asks the next question, which
is whether the answer written from that source is good. This cannot be judged by matching a
golden document, since the same fact can be written correctly in many different ways. For this
reason the answers are scored by a language model acting as a judge, through the RAGAS
framework @es2024. The three legs from before, vector, graph and hybrid, are each run all the
way to a written answer, and those answers are scored, so that the comparison started in
retrieval carries through to the final text.

Four measures are used, all defined in the theory chapter. Two of them judge the answer
itself. Faithfulness checks whether the answer stays within the retrieved context or invents
details, which makes it the hallucination check. Answer relevancy checks whether the answer
addresses the question that was asked. The other two judge the context that was retrieved to
write the answer. Context precision rewards relevant passages for appearing near the top of
the list, and so captures the signal to noise ratio of what was fed into generation. Context
recall checks whether the retrieved context held what was needed to answer.

With these four measures, each leg is taken to a full answer and scored on the same questions.
This shows whether a leg that retrieves better also produces an answer that is more faithful,
more on topic and better supported. Generation is also one half of the final comparison
between the two system versions, next to retrieval.

Two limits are worth stating. The judge is itself a language model, so its scores are a strong
signal and not a fixed truth. On the synthetic set the ground truth answers are generated and
not written by experts, so context recall against them is a softer reference, and the expert
sets remain the firmer check.

=== Trust Score Evaluation

The retrieval and generation evaluations test whether the system finds the right source and
writes a good answer. Neither of them tests whether the trust score works correctly or
whether it is helpful. The trust score therefore needs its own evaluation, with its own
dataset, built to answer two questions. Does the score reflect the quality of a document, and
does using it improve the answers the RAG gives.

Both experiments run on the Grownfield corpus, the Bosch Rexroth SAP training documentation.
Grownfield was chosen for three reasons. It carries the rich metadata that the prior needs,
which is an author, a date and a format. It covers many SAP process modules, so it holds a
wide spread of content. And every document in it was already approved by the Bosch Rexroth
team, so the originals can be treated as trustworthy, which both experiments rely on.

==== Experiment 1, Detecting a Loss of Quality

The first experiment checks whether the trust score is valid. The idea is simple. If a
document is made worse and its score drops, the score is measuring quality and not noise.
Every real Grownfield document is already good, so poor ones had to be made on purpose. For
this, 40 high quality documents were taken, and each was copied and damaged in five separate
ways. Every copy carries a single kind of damage that is aimed at a single pillar, as listed
in @tab-attacks.

#figure(
  [
    #set text(size: 10pt)
    #table(
      columns: (1fr, 1fr, 2fr),
      align: left + top,
      inset: 6pt,
      [*Damage*], [*Pillar*], [*What it does*],
      [Procedural], [Content], [Removes most of the steps of a procedure, so the process is left incomplete],
      [Technical], [Content], [Strips out SAP specifics such as transaction codes and table names, so the technical depth is lost],
      [Filler], [Content], [Injects off topic text, so the document loses its focus],
      [Authority], [Authority], [Changes the author to an unknown one],
      [Freshness], [Freshness], [Backdates the document by four years],
    )
  ],
  caption: [The five kinds of damage used in the first experiment.],
) <tab-attacks>

The three content attacks were written by a language model, and the prompt is given in the
appendix. The two metadata attacks change the author and the date directly. This produced 240
variants in all, 40 originals and 200 damaged copies, and each was scored again with the same
scorer that the pipeline uses.

Only the prior was measured in this experiment, the part built from content and metadata. The
support score depends on how the rest of the corpus corroborates a document, so recomputing it
for a single damaged copy would mean rebuilding the whole document graph each time. Its
behaviour is left to the second experiment. The score passes this test on three counts. The
damaged pillar should fall. The overall prior should fall by a smaller amount, since one weak
pillar is diluted by the others. And among the content sub scores, the attacked one should fall
the most, which shows that the damage is felt where it was done and not as a vague drop across
everything. Whether these drops are real is confirmed with a Wilcoxon signed rank test, reported
with an effect size and a correction for testing several pillars at once.

==== Experiment 2, Helping the RAG

The second experiment checks whether the trust score is useful, meaning that it helps the RAG
pick the trustworthy source when two sources disagree. A valid score is only worth adding if it
changes the answers for the better, and this experiment is built to show that directly.

For this experiment, 20 fact rich documents were taken, and a poisoned twin of each was made by
a language model that flips about ten of its facts and weakens its metadata. The poisoning
prompt is given in the appendix. This gives a corpus of 40 documents, 20 real ones and 20
twins, where a real document and its twin answer the same question in conflicting ways.
Building the conflict this way is deliberate. A twin shares the topic and the wording of the
original but carries wrong facts, so any question drawn from it has one clearly correct source
and one clearly wrong one, which is exactly the situation that the trust score is meant to
resolve. Every flipped fact became a question with a known correct value and the wrong value of
the twin, which gives 190 questions.

All 40 documents were indexed in the vector store, and each twin was placed into the real
Grownfield graph, so that its support score could be computed by the same walk that is used in
retrieval. Trust then enters the RAG in two places. It reweights the ranking after reranking by
the factor $(1 + beta_t dot.op "trust")$, as described in the retrieval implementation, and each
retrieved chunk is also tagged with its trust value in the prompt, so that the model knows which
source to follow when two conflict.

To isolate what trust contributes, the same questions are run three times in an ablation, once
with trust off, once with the prior alone, and once with the full score of prior and support
together. Comparing the three shows whether trust helps at all and whether the support score
adds anything beyond the prior. Each run is checked in two ways. The retrieval check asks
whether the good document is ranked above its poisoned twin. The generation check asks whether
the written answer follows the correct value and not the wrong value of the twin. Because the
three runs share the same questions, their differences are tested with a McNemar test, the
paired test for two settings scored on the same items.

The answers are graded in three ways, by exact keyword match, by a custom language model judge
whose instructions are given in the appendix, and by RAGAS. Each grader is first checked against
the known correct value. This decides which grader can be trusted for the final reading, and
avoids assuming that any single grader is reliable on its own. The two experiments test both
sides of the claim. The first shows that the score reflects real quality, and the second shows
that it improves the answers.

== Observability

A RAG pipeline handles both retrieval and generation. It fetches the relevant documents and
then answers the question. Along the way it searches the vector store, walks the graph, fuses
and reranks the candidates, folds in trust, and finally calls the language model. When an
answer comes out wrong, the cause can lie in any one of these steps, and reading the final
answer alone does not reveal which one failed. The pipeline therefore has to be monitored, so
that each request can be opened up and inspected after it runs. Scattering manual log
statements through the code is one way to do this, but it is slow to write and painful to
debug when something breaks. A dedicated tracing tool was used instead, which helps not only
with monitoring but also with later improvements.

Several tools offer this kind of tracing, and Opik was chosen because it is open source and
can be run on the own infrastructure of the project. This keeps the traces and their data
inside the same environment as the rest of the system and does not send them to an outside
service, which matters for enterprise material that should not leave the local setup. The
application talks to Opik as a client and sends everything it records to a local server,
where it is viewed in a dashboard. A small set of environment variables points the client at
the server, names the project under which all traces are grouped, and sets the workspace.

The three levels of recording introduced in the theory chapter map directly onto the way the
system is used. A span is one function call of the pipeline, a trace is one question from
entry to answer, and a thread is one session. A person usually asks several questions in one
sitting, and each question runs the whole pipeline once, so every question becomes one trace
and the traces of one conversation are grouped into one thread.

The recording is done with a decorator. Placing it above a function tells Opik to capture
that function as a span each time it runs, taking its inputs before it executes and its
result and timing after. When one decorated function calls another, the inner span is nested
inside the outer one, so the shape of the pipeline is rebuilt as a tree without any manual
bookkeeping. The top of the tree is the whole request, recorded as `rag_pipeline`, and
beneath it sit the retrieval and generation steps. Retrieval opens its own nested spans for
the vector search, the graph traversal, the fusion and its union, the reranker and the
recommended documents, so that the path of a question through the two legs is visible step
by step.

Where the automatic capture is not enough, two calls add more detail. One attaches step level
detail to the current span, such as how many chunks each leg returned, together with the
token usage and the estimated cost of a model call. The other attaches request level detail
to the current trace, such as the final answer and the session identifier. The session
identifier is a single value that is created once when a session opens and reused for every
question in it, which is what files the separate traces under one conversation.

Observability was not part of the baseline, which offered no way to trace or measure the
pipeline. Adding it makes both the behaviour and the cost of each request transparent. This
visibility is what allowed the retrieval approaches and the trust score to be understood and
debugged while they were being built.

=== Guidelines for Trustworthy Documents

The trust score is only useful if the teams that write training material know what it rewards.
For this reason the score is translated into a short set of writing guidelines. They follow
directly from the way the score is built. The score does not check whether the information in
a document is factually right. It estimates how reliable a document is from its content
quality, its metadata and how well it aligns with the rest of the knowledge base. A document
that follows the guidelines therefore has a higher chance of earning a good score.

Because the prior carries a weight of 0.7 and the support score a weight of 0.3, the share of
each part in the final score follows from the weights of the pillars. The content pillar
contributes $0.7 dot.op 0.45 = 31.5%$, the three metadata pillars contribute
$0.7 dot.op (0.25 + 0.15 + 0.15) = 38.5%$, and the support score contributes 30%. 
@tab-guidelines lists the three parts and what each of them rewards.

#figure(
  [
    #set text(size: 10pt)
    #table(
      columns: (1fr, 0.7fr, 3fr),
      align: left + top,
      inset: 6pt,
      [*Part*], [*Share*], [*What it rewards*],
      [Content], [31.5%],
        [Specific details such as transaction codes, table names, program names, fields and
        item types. A complete procedure with prerequisites, steps and outcome. Actionable
        steps that say what to enter or click and why. A focused document with one task or
        topic, free of filler and of descriptions of slide visuals.],
      [Metadata], [38.5%],
        [A known and authorised author and no blank or unknown author. A recent last
        modified date, kept current by reviewing and saving the document regularly. A
        structured, text based format, preferred over image only slides, so that the content
        is machine readable.],
      [Support], [30%],
        [Standard and consistent terminology, so that the document links into the shared
        knowledge graph. Facts that agree with other trusted documents. A document that
        shares its key facts with the wider corpus and does not stand in isolation.],
    )
  ],
  caption: [Writing guidelines derived from the three parts of the trust score and their share of the final score.],
) <tab-guidelines>

The guidelines for the support score deserve a note. Using the same codes and names as other
official documents is what connects a document to the others through shared entities, and
without such connections it keeps only its prior. Agreement with trusted documents raises the
score, but as discussed above, agreement is only a proxy for correctness. The guidelines
therefore ask authors to stay consistent with authoritative sources, and they do not ask them
to copy the majority.
// CONFIRM: your draft sentence on the support rule was cut off after "earn corroboration". I assumed that contradictory facts earn none.
