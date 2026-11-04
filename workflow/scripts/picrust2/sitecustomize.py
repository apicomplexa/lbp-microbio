# Imported automatically by every Python process that has this directory on
# PYTHONPATH (picrust2_pipeline.py and the hsp.py / place_seqs.py it spawns).
#
# With thousands of ASVs nearly all bacterial sequences get placed into the
# archaeal reference tree too, stacking up into a newick nesting thousands of
# levels deep; dendropy parses it recursively and fails in prune_tree() with
# "RecursionError: maximum recursion depth exceeded" at the default limit (1000).
import sys

sys.setrecursionlimit(100_000)
