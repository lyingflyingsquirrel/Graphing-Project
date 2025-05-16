from sage.all import *
import os
import sys # For printing to stderr from worker


# --- Determine paths relative to this worker_funcs.py file ---
_WORKER_DIR = os.path.dirname(os.path.abspath(__file__))
_PACKAGES_DIR = os.path.join(_WORKER_DIR, 'Packages')

try:
    print(f"WORKER (pid {os.getpid()}): Loading {os.path.join(_PACKAGES_DIR, 'balancefunctions.sage')}...", file=sys.stderr)
    load(os.path.join(_PACKAGES_DIR, 'balancefunctions.sage'))
    
    # If graph_theory.py's 'invariants' list provides other top-level named functions you are using by name:
    print(f"WORKER (pid {os.getpid()}): Loading {os.path.join(_PACKAGES_DIR, 'graph_theory.py')}...", file=sys.stderr)
    load(os.path.join(_PACKAGES_DIR, 'graph_theory.py'))
    
    print(f"WORKER (pid {os.getpid()}): Finished loading dependency scripts.", file=sys.stderr)
except Exception as e:
    print(f"WORKER (pid {os.getpid()}): ERROR loading dependency scripts: {type(e).__name__}: {e}", file=sys.stderr)

def _compute_invariant_value_worker(invariant_func_name_to_call, graph_as_g6string, results_dict):
    """
    Worker function to compute an invariant value for a graph.
    It looks up invariant_func_name_to_call in its own global scope.
    """
    g6_key = graph_as_g6string 
    inv_name_key = invariant_func_name_to_call
    
    try:
        graph_obj = Graph(graph_as_g6string) # Recreate graph object in the worker

        # Get the actual invariant function from this worker's global scope
        # (populated by the load() commands at the top of this file)
        if invariant_func_name_to_call not in globals():
            raise NameError(f"Invariant function '{invariant_func_name_to_call}' not found in worker's global scope. Check load() statements in worker_funcs.py.")
        
        actual_invariant_func = globals()[invariant_func_name_to_call]
        
        value = float(actual_invariant_func(graph_obj)) 
        results_dict[(inv_name_key, g6_key)] = value
    except Exception as e:
        error_message = f"Error: {type(e).__name__} - {str(e)[:150]}" # Keep error message concise
        results_dict[(inv_name_key, g6_key)] = error_message 
        # This print helps debug worker-specific issues if they don't propagate well
        print(f"WORKER (pid {os.getpid()}) ERROR computing {inv_name_key} for graph {g6_key}: {error_message}", file=sys.stderr)


def _compute_property_value_worker(property_func_name_to_call, graph_as_g6string, results_dict):
    """
    Worker function to compute a property value for a graph.
    Looks up property_func_name_to_call in its own global scope.
    """
    g6_key = graph_as_g6string
    prop_name_key = property_func_name_to_call
    try:
        graph_obj = Graph(graph_as_g6string)

        if property_func_name_to_call not in globals():
            raise NameError(f"Property function '{property_func_name_to_call}' not found in worker's global scope. Check load() statements in worker_funcs.py.")
            
        actual_property_func = globals()[property_func_name_to_call]

        value = bool(actual_property_func(graph_obj))
        results_dict[(prop_name_key, g6_key)] = value
    except Exception as e:
        error_message = f"Error: {type(e).__name__} - {str(e)[:150]}"
        results_dict[(prop_name_key, g6_key)] = error_message
        print(f"WORKER (pid {os.getpid()}) ERROR computing {prop_name_key} for graph {g6_key}: {error_message}", file=sys.stderr)