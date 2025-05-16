# Presumed filename: gt_precomputed_database.sage
"""
This file implements the creation and usage of a database of precomputed values
for graphs, invariants, and properties.

EXAMPLE::

    sage: load("gt.sage") # Assuming gt.sage contains graph objects, invariants, properties definitions
    sage: load("gt_precomputed_database.sage") # This file
    sage: create_tables() # Initialize the database
    # Assuming 'my_invariants_list' and 'my_graphs_list' are defined:
    sage: update_invariant_database(my_invariants_list, my_graphs_list, timeout=5)
    # Assuming 'my_properties_list' is defined:
    sage: update_property_database(my_properties_list, my_graphs_list, timeout=5)
"""
from sage.all import *

import sqlite3
import multiprocessing
import os # For dump_database


try:
    from worker_funcs import _compute_invariant_value_worker, _compute_property_value_worker
    print("Successfully imported worker functions into gt_precomputed_database.sage.")
except ImportError:
    print("ERROR in gt_precomputed_database.sage: Could not import from worker_funcs.py.")
    print("Ensure worker_funcs.py is in the correct location (usually same as your main notebook).")
    # Define dummy workers so the rest of this file doesn't break on definition,
    # but multiprocessing will fail later if these dummies are used.
    def _compute_invariant_value_worker(*args): raise NotImplementedError("Worker not imported")
    def _compute_property_value_worker(*args): raise NotImplementedError("Worker not imported")

SKIP_LIST_FILENAME_TIMEOUTS_ONLY = "skip_timeouts_log.txt"

def load_timeout_skip_list():
    """Loads a set of 'invariant_name,graph6_key' strings that previously timed out."""
    skip_set = set()
    # The notebook's CWD will be used here when this function is called from the notebook
    if os.path.exists(SKIP_LIST_FILENAME_TIMEOUTS_ONLY):
        try:
            with open(SKIP_LIST_FILENAME_TIMEOUTS_ONLY, 'r') as f:
                for line in f:
                    entry = line.strip()
                    if entry:
                        skip_set.add(entry)
            print(f"DEBUG: Loaded {len(skip_set)} entries from skip list: {SKIP_LIST_FILENAME_TIMEOUTS_ONLY}", file=sys.stderr)
        except Exception as e:
            print(f"Warning: Could not read timeout skip list file '{SKIP_LIST_FILENAME_TIMEOUTS_ONLY}': {e}", file=sys.stderr)
    else:
        print(f"DEBUG: Skip list file not found: {SKIP_LIST_FILENAME_TIMEOUTS_ONLY}. A new one may be created if timeouts occur.", file=sys.stderr)
    return skip_set

def add_to_timeout_skip_list(invariant_name, graph_key):
    """Adds an invariant/graph pair to the timeout skip list file."""
    entry = f"{invariant_name},{graph_key}"
    try:
        with open(SKIP_LIST_FILENAME_TIMEOUTS_ONLY, 'a') as f:
            f.write(f"{entry}\n")
        print(f"TIMED OUT & LOGGED TO SKIP: {entry} (in {os.path.abspath(SKIP_LIST_FILENAME_TIMEOUTS_ONLY)})")
    except Exception as e:
        print(f"Warning: Could not write to timeout skip list file '{SKIP_LIST_FILENAME_TIMEOUTS_ONLY}': {e}")


def get_connection(database_file=None):
    """
    Returns a connection to the database. If no name is provided, this method
    will by default open a connection with a database called gt_precomputed_database.db
    located in the current working directory.
    """
    if database_file is None:
        database_file = "gt_precomputed_database.db"
    return sqlite3.connect(database_file)

def create_tables(database_file=None):
    """
    Sets up the database for use by the other methods, i.e., this method creates
    the necessary tables in the database. It is safe to run this method even if
    the tables already exist.
    """
    with get_connection(database_file) as conn:
        conn.execute("CREATE TABLE IF NOT EXISTS inv_values (invariant TEXT, graph TEXT, value FLOAT, UNIQUE(invariant, graph))")
        conn.execute("CREATE TABLE IF NOT EXISTS prop_values (property TEXT, graph TEXT, value BOOLEAN, UNIQUE(property, graph))")
        # No need for conn.close() due to 'with' statement

def invariants_as_dict(database_file=None):
    """
    Returns a dictionary containing for each graph (by its graph6_string) a 
    dictionary mapping each invariant name to its value.
    """
    d = {}
    with get_connection(database_file) as conn:
        result = conn.execute("SELECT invariant, graph, value FROM inv_values")
        for (i, g_key, v) in result:
            if g_key not in d:
                d[g_key] = {}
            d[g_key][i] = v
    return d

def precomputed_invariants_for_conjecture(database_file=None):
    """
    Returns a tuple of length 3 that can be used for the conjecture method of
    conjecturing.py, using graph6_string as the graph key.
    """
    # The conjecturing.py might expect graph objects as keys in the first dict.
    # This function currently returns graph6_strings as keys.
    # Adapt if conjecturing.py needs actual graph objects (would require deserializing graphs).
    # For now, assuming graph6_string keys are acceptable or can be adapted.
    return (invariants_as_dict(database_file), 
            (lambda g: g.canonical_label(algorithm='sage').graph6_string()), 
            (lambda f: f.__name__))

def properties_as_dict(database_file=None):
    """
    Returns a dictionary containing for each graph (by its graph6_string) a 
    dictionary mapping each property name to its boolean value.
    """
    d = {}
    with get_connection(database_file) as conn:
        result = conn.execute("SELECT property, graph, value FROM prop_values")
        for (p, g_key, v) in result:
            if g_key not in d:
                d[g_key] = {}
            d[g_key][p] = bool(v)
    return d

def precomputed_properties_for_conjecture(database_file=None):
    """
    Returns a tuple of length 3 that can be used for the propertyBasedConjecture
    method of conjecturing.py.
    """
    return (properties_as_dict(database_file), 
            (lambda g: g.canonical_label(algorithm='sage').graph6_string()), 
            (lambda f: f.__name__))

# def _compute_invariant_value_worker(invariant_func, graph_obj, results_dict):
    """
    Worker function to compute invariant value. Handles potential errors.
    (Internal use for multiprocessing)
    """
    g_key = graph_obj.canonical_label(algorithm='sage').graph6_string()
    inv_name = invariant_func.__name__
    try:
        value = float(invariant_func(graph_obj))
        results_dict[(inv_name, g_key)] = value
    except Exception as e:
        # Optionally store the error or a specific marker
        results_dict[(inv_name, g_key)] = f"Error: {type(e).__name__}" 
        print(f"Error computing {inv_name} for graph {g_key}: {e}")


def update_invariant_database(invariants_list, graphs_list, timeout=60, database_file=None, verbose=False):
    """
    Tries to compute and store invariant values.
    Skips pairs that previously timed out, based on 'skip_timeouts_log.txt'.
    """
    current_db_values = invariants_as_dict(database_file)
    timeout_skip_list = load_timeout_skip_list() # Load the timeout skip list
    
    manager = multiprocessing.Manager()
    computation_results = manager.dict()

    with get_connection(database_file) as conn:
        for inv_func in invariants_list:
            inv_name = inv_func.__name__
            # We don't skip the entire invariant function anymore, only specific pairs that timed out.

            for g_obj in graphs_list:
                g_key = g_obj.canonical_label(algorithm='sage').graph6_string()
                graph_id_for_print = g_obj.name() if g_obj.name() else g_key
                
                # Check if this specific invariant/graph pair is in the timeout skip list
                pair_key_for_skip = f"{inv_name},{g_key}"
                if pair_key_for_skip in timeout_skip_list:
                    if verbose:
                        print(f"Skipping {inv_name} for graph {graph_id_for_print} ({g_key}) due to previous timeout.")
                    continue

                # Check if value is already in the database (this is for successful computations)
                if g_key in current_db_values and inv_name in current_db_values[g_key]:
                    if verbose:
                        print(f"Value for {inv_name} of graph {graph_id_for_print} ({g_key}) already in DB.")
                    continue

                if verbose:
                    print(f"  Dispatching computation: {inv_name} for graph {graph_id_for_print} ({g_key})...")
                
                p = multiprocessing.Process(target=_compute_invariant_value_worker, 
                                            args=(inv_name, g_key, computation_results))
                p.start()
                p.join(timeout)

                if p.is_alive():
                    print(f"Computation of {inv_name} for graph {graph_id_for_print} ({g_key}) timed out... killing!")
                    p.terminate()
                    p.join()
                    # Log ONLY this timeout to skip this specific pair next time
                    add_to_timeout_skip_list(inv_name, g_key) 
                else:
                    result_key = (inv_name, g_key)
                    if result_key in computation_results:
                        value = computation_results[result_key]
                        if isinstance(value, (int, float)): # Check if it's a valid number
                            conn.execute("INSERT OR REPLACE INTO inv_values(invariant, graph, value) VALUES (?,?,?)",
                                         (inv_name, g_key, value))
                            conn.commit()
                            if verbose:
                                print(f"Stored {inv_name} for {graph_id_for_print}: {value}")
                        else: # An error string was stored from the worker
                            print(f"Computation of {inv_name} for {graph_id_for_print} resulted in an error from worker: {value}")
                            # NOT adding to skip list for general errors, only timeouts
                    else:
                        print(f"Computation of {inv_name} for {graph_id_for_print} failed (no result captured from worker).")
                        # NOT adding to skip list for this, only timeouts
            if verbose:
                print(f"Finished processing for invariant: {inv_name}")

def store_invariant_value(invariant_func, graph_obj, value, overwrite=False, database_file=None, epsilon=1e-8, verbose=False):
    """
    Stores a given invariant value in the database.
    """
    i_key = invariant_func.__name__
    g_key = graph_obj.canonical_label(algorithm='sage').graph6_string()
    graph_id_for_print = graph_obj.name() if graph_obj.name() else g_key
    
    processed_value = float(value)

    with get_connection(database_file) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM inv_values WHERE invariant=? AND graph=?", (i_key, g_key))
        result = cursor.fetchone()

        if not overwrite and result is not None:
            stored_value = result[0]
            if abs(processed_value - stored_value) > epsilon:
                print(f"Warning: Stored value of {i_key} for {graph_id_for_print} ({stored_value}) "
                      f"differs from provided value ({processed_value}). Not overwriting.")
            elif verbose:
                print(f"Value of {i_key} for {graph_id_for_print} is already in the database and matches.")
            return

        if result is None:
            conn.execute("INSERT INTO inv_values(invariant, graph, value) VALUES (?,?,?)",
                         (i_key, g_key, processed_value))
        else: # Result exists, and overwrite is True or values were different enough (and overwrite=True implicitly)
            conn.execute("UPDATE inv_values SET value=? WHERE invariant=? AND graph=?",
                         (processed_value, i_key, g_key))
        conn.commit()
        if verbose:
            print(f"Stored value of {i_key} for {graph_id_for_print}: {processed_value}")

def list_missing_invariants(invariants_list, graphs_list, database_file=None):
    """
    Prints a list of invariant/graph pairs not in the database.
    """
    current_db_values = invariants_as_dict(database_file)
    for inv_func in invariants_list:
        inv_name = inv_func.__name__
        for g_obj in graphs_list:
            g_key = g_obj.canonical_label(algorithm='sage').graph6_string()
            graph_id_for_print = g_obj.name() if g_obj.name() else g_key
            if not (g_key in current_db_values and inv_name in current_db_values[g_key]):
                print(f"Missing: {inv_name} for graph {graph_id_for_print} ({g_key})")

# --- Property related functions would follow a similar cleanup pattern ---
# For brevity, I'll show one example for properties and you can apply to others.

# def _compute_property_value_worker(property_func, graph_obj, results_dict):
#     """Worker function to compute property value. Handles potential errors."""
#     g_key = graph_obj.canonical_label(algorithm='sage').graph6_string()
#     prop_name = property_func.__name__
#     try:
#         value = bool(property_func(graph_obj))
#         results_dict[(prop_name, g_key)] = value
#     except Exception as e:
#         results_dict[(prop_name, g_key)] = f"Error: {type(e).__name__}"
#         print(f"Error computing {prop_name} for graph {g_key}: {e}")

def update_property_database(properties_list, graphs_list, timeout=60, database_file=None, verbose=False):
    """
    Tries to compute and store property values.
    Skips pairs that previously timed out. (Similar logic to invariants)
    """
    current_db_values = properties_as_dict(database_file)
    timeout_skip_list = load_timeout_skip_list() # Use the same timeout skip list concept
    
    manager = multiprocessing.Manager()
    computation_results = manager.dict()

    with get_connection(database_file) as conn:
        for prop_func in properties_list:
            prop_name = prop_func.__name__

            for g_obj in graphs_list:
                g_key = g_obj.canonical_label(algorithm='sage').graph6_string()
                graph_id_for_print = g_obj.name() if g_obj.name() else g_key

                pair_key_for_skip = f"{prop_name},{g_key}"
                if pair_key_for_skip in timeout_skip_list:
                    if verbose:
                        print(f"Skipping property {prop_name} for graph {graph_id_for_print} ({g_key}) due to previous timeout.")
                    continue
                
                if g_key in current_db_values and prop_name in current_db_values[g_key]:
                    if verbose:
                        print(f"Value for {prop_name} of graph {graph_id_for_print} already in DB.")
                    continue
                
                if verbose:
                    print(f"  Dispatching computation: {prop_name} for graph {graph_id_for_print} ({g_key})...")

                p = multiprocessing.Process(target=_compute_property_value_worker, 
                                            args=(prop_name, g_key, computation_results))
                p.start()
                p.join(timeout)

                if p.is_alive():
                    print(f"Computation of {prop_name} for graph {graph_id_for_print} timed out... killing!")
                    p.terminate()
                    p.join()
                    add_to_timeout_skip_list(prop_name, g_key) # Log timeout
                else:
                    result_key = (prop_name, g_key)
                    if result_key in computation_results:
                        value = computation_results[result_key]
                        if isinstance(value, bool): 
                            conn.execute("INSERT OR REPLACE INTO prop_values(property, graph, value) VALUES (?,?,?)",
                                         (prop_name, g_key, value))
                            conn.commit()
                            if verbose:
                                print(f"Stored {prop_name} for {graph_id_for_print}: {value}")
                        else: 
                             print(f"Computation of {prop_name} for {graph_id_for_print} resulted in an error from worker: {value}")
                    else:
                        print(f"Computation of {prop_name} for {graph_id_for_print} failed (no result captured).")
            if verbose:
                print(f"Finished processing for property: {prop_name}")

# Apply similar cleanup (Python 3 print, f-strings, 'with' for db, robust graph IDs)
# to: store_property_value, list_missing_properties, verify_invariant_values, verify_property_values

def dump_database(folder="db_dump", database_file=None): # Changed default folder name
    """
    Writes the specified database to a series of SQL files in the specified folder.
    """
    # Ensure all necessary folders exist
    inv_folder = os.path.join(folder, 'invariants')
    prop_folder = os.path.join(folder, 'properties')
    os.makedirs(inv_folder, exist_ok=True)
    os.makedirs(prop_folder, exist_ok=True)

    with get_connection(database_file) as conn:
        # Dump the table with invariant values
        current_invariants = invariants_as_dict(database_file)
        inv_names = set()
        for g_key in current_invariants:
            inv_names.update(current_invariants[g_key].keys())

        for inv_name in sorted(list(inv_names)):
            filepath = os.path.join(inv_folder, f"{inv_name}.sql")
            with open(filepath, 'w') as f:
                # Use parameterized query to avoid SQL injection, though here it's for constructing INSERTs
                # The original method of selecting and then formatting is okay for this specific dump purpose.
                q = "SELECT 'INSERT INTO \"inv_values\" VALUES('||quote(invariant)||','||quote(graph)||','||quote(value)||')' FROM 'inv_values' WHERE invariant=? ORDER BY graph ASC"
                query_res = conn.execute(q, (inv_name,))
                for row in query_res:
                    s = row[0]
                    # Fix issue with sqlite3 not being able to read its own output for infinity
                    if s.endswith(',Inf)'): # Check standard float('inf') representation
                        s = s[:-5] + ", '1e300')" # Use a very large number string
                    elif s.endswith(',-Inf)'):
                        s = s[:-6] + ", '-1e300')"
                    elif s.endswith(',Infinity)'): # Sage's infinity might stringify differently
                        s = s[:-10] + ", '1e300')"
                    elif s.endswith(',-Infinity)'):
                        s = s[:-11] + ", '-1e300')"
                    f.write(f"{s};\n")
        print(f"Invariant tables dumped to: {inv_folder}")

        # Dump the table with property values
        current_properties = properties_as_dict(database_file)
        prop_names = set()
        for g_key in current_properties:
            prop_names.update(current_properties[g_key].keys())

        for prop_name in sorted(list(prop_names)):
            filepath = os.path.join(prop_folder, f"{prop_name}.sql")
            with open(filepath, 'w') as f:
                q = "SELECT 'INSERT INTO \"prop_values\" VALUES('||quote(property)||','||quote(graph)||','||quote(value)||')' FROM 'prop_values' WHERE property=? ORDER BY graph ASC"
                query_res = conn.execute(q, (prop_name,))
                for row in query_res:
                    f.write(f"{row[0]};\n") # Boolean values (0 or 1) should be fine
        print(f"Property tables dumped to: {prop_folder}")

print("Database utility functions defined and cleaned up for Python 3.")
# You would typically load this file in Sage and then call these functions.
# e.g., create_tables()
#       update_invariant_database(...)