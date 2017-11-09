#!/usr/bin/python

import argparse
import os
import glob
import re
import time
import sys
import fnmatch
import pickle
from prettytable import PrettyTable # Install via: easy_install PrettyTable

def find_fstar_output_files(directory):
    matches = []
    extensions = ["vfsti", "vfst"]

    # Based on: https://stackoverflow.com/a/2186565
    for root, dirnames, filenames in os.walk(directory):
        for ext in extensions:
            for filename in fnmatch.filter(filenames, '*.' + ext):
                matches.append(os.path.join(root, filename))
    return matches

def parse_fstar_output(filename):
    time = 0
    found = False
    with open(filename, "r") as f:
        for line in f.readlines():
            result = re.search("Verified.*\((\d+) milliseconds\)", line)
            if result:
                time += int(result.group(1))
                found = True
            
    if found:
        return time
    else:
        return None

def collect_times_dir(d):
    files = find_fstar_output_files(d)
    times = {}
    for f in files:
        times[f] = parse_fstar_output(f)
    return times

def collect_times(directories):
    times = {}
    for d in directories:
        times.update(collect_times_dir(d))
    return times

def display_times(times):
    tab = PrettyTable(["Filename", "Time", "Full Path"])
    tab.align["Filename"] = "l"
    tab.align["Time"] = "r"
    tab.align["FullPath"] = "l"

    total_time = 0

    for f in sorted(times.keys()):
        filename = os.path.basename(f)
        tab.add_row([filename, times[f], f])
        if not times[f] is None:
            total_time += times[f]
    
    tab.add_row(["", "", ""])
    tab.add_row(["Total", total_time, ""])
    print(tab)

def store_times(times, label):
    pickle_file = "times." + label + ".pickle"
    if not os.path.isfile(pickle_file):
        with open(pickle_file, "wb") as pickler:
            pickle.dump(times, pickler)
    else:
        print "WARNING: Found existing pickled file %s.  No data written.  Consider moving or deleting it." % pickle_file

def load_times(filename):
    with open(filename, "rb") as pickler:
        return pickle.load(pickler)

def compute_diff(times1, times2):
    diffs = {}
    for f,t in times1.items():
        if f in times2 and not t is None:
            diffs[f] = t - times2[f]

    return diffs

def display_diffs(times, diffs):
    tab = PrettyTable(["Filename", "t1 time", "delta", "delta \%","Full Path"])
    tab.align["Filename"] = "l"
    tab.align["t1 time"] = "r"
    tab.align["delta"] = "r"
    tab.align["delta \%"] = "r"
    tab.align["FullPath"] = "l"
    tab.sortby = "delta"

    total_time = 0
    total_delta = 0

    for f in sorted(times.keys()):
        filename = os.path.basename(f)
        delta = "n/a"
        delta_percent = "n/a"
        if f in diffs:
            delta = diffs[f]
            delta_percent = "%0.1f" % (delta / float(times[f]))
        tab.add_row([filename, times[f], delta, delta_percent, f])
        if not times[f] is None:
            total_time += times[f]
            total_delta += delta
    
    tab.add_row(["", "", "", "", ""])
    #tab.add_row(["Total", total_time, total_delta, total_delta / float(total_time), ""])
    print(tab)

def main():
    parser = argparse.ArgumentParser(description= 'Collect and summarize F* verification times')
    parser.add_argument('--dir', action='append', required=False, help='Collect all results in this folder and its subfolders')
    parser.add_argument('--label', action='store', required=False, help='Label for file containing the results')
    parser.add_argument('--t1', action='store', required=False, help='File of times to compare to t2')
    parser.add_argument('--t2', action='store', required=False, help='File of times to compare to t1')

    args = parser.parse_args()

    if (not args.dir is None) and (not args.label is None):
        times = collect_times(args.dir)
        display_times(times)
        store_times(times, args.label)
        sys.exit(0)

    if (not args.t1 is None) and (not args.t2 is None):
        times1 = load_times(args.t1)
        times2 = load_times(args.t2)
        diffs = compute_diff(times1, times2)
        display_diffs(times1, diffs)
        sys.exit(0)

    print("Invalid or insufficient arguments supplied.  Try running with -h")

if (__name__=="__main__"):
  main()

