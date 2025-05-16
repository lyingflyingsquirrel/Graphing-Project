# File: check_g6_strings.sage
import re
from sage.all import Graph # To use the Graph() constructor for parsing
import os # To construct paths reliably

# --- Configuration: Set the path to your gt.sage file ---
# Assuming gt.sage is in the same directory as this check_g6_strings.sage script
script_dir = os.path.dirname(os.path.abspath(__file__))
gt_sage_filename = "gt.sage" # The name of the file to check
gt_sage_filepath = os.path.join(script_dir, gt_sage_filename)
# --- End Configuration ---

# Regex to find lines like: some_var = Graph(r"g6_string_content")
# This regex looks for Graph(r"...") or Graph(r'...')
graph_def_pattern = re.compile(r"Graph\s*\(\s*r([\"'])([^\"']*)\1\s*\)")
# Group 1 captures the quote type, Group 2 captures the g6 string content

problematic_graphs_info = []

print(f"Checking file: {gt_sage_filepath}\n")

try:
    with open(gt_sage_filepath, 'r', encoding='utf-8') as f:
        for line_num, line_text in enumerate(f, 1):
            # Check only lines that seem to define a graph with a raw string
            if "Graph(r" in line_text:
                match = graph_def_pattern.search(line_text)
                if match:
                    g6_string = match.group(2) # Get the content of the g6 string
                    try:
                        # Try to create the graph to see if Sage's parser flags it
                        G_test = Graph(g6_string) # Pass the raw string content
                        # If no error, it's okay by Sage's parser for now
                    except RuntimeError as e:
                        if "seems corrupt" in str(e).lower() and ("too long" in str(e).lower() or "too short" in str(e).lower()):
                            problematic_graphs_info.append({
                                "line_num": line_num,
                                "error_summary": str(e).split(':')[-1].strip(), # Get the core error part
                                "line_content": line_text.strip()
                            })
                        else: # Other RuntimeErrors during Graph()
                            problematic_graphs_info.append({
                                "line_num": line_num,
                                "error_summary": f"Other RuntimeError: {str(e)[:100]}...", # Truncate long errors
                                "line_content": line_text.strip()
                            })
                    except Exception as e: # Other unexpected errors during Graph()
                        problematic_graphs_info.append({
                                "line_num": line_num,
                                "error_summary": f"Unexpected error: {str(e)[:100]}...",
                                "line_content": line_text.strip()
                            })
except FileNotFoundError:
    print(f"ERROR: Could not find the file {gt_sage_filepath}")
    print("Please ensure 'gt_sage_filepath' is set correctly at the top of this script.")
    import sys
    sys.exit(1)
except Exception as e_file:
    print(f"An error occurred reading the file: {e_file}")
    import sys
    sys.exit(1)


# --- Output Section ---
if problematic_graphs_info:
    print("\n--- Summary of Problematic Graph Definitions ---")
    print(f"Found {len(problematic_graphs_info)} lines with graph6 string parsing errors in '{gt_sage_filepath}'.")

    print("\nDetailed list of problematic lines and errors:")
    for p_info in problematic_graphs_info:
        print(f"  Line {p_info['line_num']}: {p_info['line_content']}")
        print(f"     Error: {p_info['error_summary']}")

    # --- Outputting all problematic line numbers together ---
    print("\n----------------------------------------------------")
    print("Line numbers of all problematic graph definitions:")
    print("----------------------------------------------------")
    line_numbers = sorted(list(set([p['line_num'] for p in problematic_graphs_info])))
    if line_numbers:
        for ln in line_numbers:
            print(ln)
        print(f"\nConsider commenting out these {len(line_numbers)} lines in '{gt_sage_filename}' to allow the rest of the file to load.")
    else: # Should not happen if problematic_graphs_info is not empty
        print("No line numbers extracted, though problems were reported (this is unexpected).")
    print("----------------------------------------------------")

else:
    print("No graph6 string corruption errors (like 'string too long/short') found by this check.")
    print("If you still have SyntaxWarnings for 'invalid escape sequence' in gt.sage,")
    print("ensure all graph strings containing backslashes are raw strings (e.g., Graph(r\"...\")).")