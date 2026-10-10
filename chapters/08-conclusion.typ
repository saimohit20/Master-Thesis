= Conclusion

This thesis began with a simple tension. The Bosch Rexroth Academy held a large and growing body of
training material, and its first learning assistant could already answer questions from it, yet the
answers were only as good as the sources behind them, and there was no dependable way to tell a
reliable source from a doubtful one. The first version leaned on semantic vector search and on a
manual trust rating that most documents never received. The goal of this work was to close that gap
and turn AVAILABLE into a system that is not only fluent but also accurate and honest about where its
answers come from.

The first step was to stop guessing and start measuring. An evaluation harness and full tracing of the
pipeline with Opik made it possible to see where the baseline actually broke, and the picture was
clear: the weakness lay in retrieval rather than in the language model. The right document was too
often buried below the top of the results, and the manual trust ratings that were meant to protect the
user were, in practice, almost never there. Everything that followed grew out of these two findings.

The answer to the retrieval problem was to give the system a second way of looking. Alongside vector
search, a knowledge graph now connects chunks through the entities they share, so that related content
can be found even when a question and a document use different words. Joined together, the two legs
lifted retrieval where it matters most, at the very top of the ranking. The correct document reached
the first position far more often across every dataset, with Hit\@1 climbing from 0.39 to 0.66 on
Grownfield, from 0.68 to 0.95 on Hydraulics and from 0.56 to 0.68 on the synthetic set, while the wider
reach of the hybrid pool raised Hit\@10 from 0.86 to 0.97. Cleaner retrieval carried straight into the
answers, most visibly in context precision, which roughly doubled on Grownfield from 0.36 to 0.77. A
closer look at the reranker added a practical lesson of its own: the expensive cross-encoder barely
changed the answers, so switching it off cut the time per question from 28.9 to 13.4 seconds with
almost nothing lost.

Trust was rebuilt from the ground up. Instead of waiting for someone to rate a document by hand, every
document now earns a score at ingestion, drawn from its own content and metadata and tempered by how
well the rest of the corpus supports it. Put to the test against poisoned near-copies of trusted
sources, this score nearly doubled the share of questions in which the genuine document won out, from
38.4% to 71.1%, and all but eliminated the hedged answers that name both the right and the wrong value,
from 42 down to 1 out of 190. Where the score struggled, against a near-perfect forgery that borrows
its neighbours' good standing, it mapped out the honest boundary of what a corroboration signal can do.

What remains is a learning assistant that finds the right source more often, judges that source before
it is ever shown, and can be watched and measured at every step. It does this on real material that is
multilingual and spread across slides, documents and video, which is exactly the setting where such
systems are hardest to build and most worth having. The road does not end here, and the directions
still open are taken up in the chapter that follows.
