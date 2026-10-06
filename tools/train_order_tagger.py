#!/usr/bin/env python3
"""Train the BERT order tagger on data from generate_order_dataset.py.

Both the action loss and the word-tag loss are summed and the whole encoder is
fine-tuned. The report scores the dev and test splits and the hand-written
evaluator cases. Needs PyTorch and transformers.
"""

import argparse
import json
from pathlib import Path
import random
import statistics
import time

import torch
from torch import nn
from transformers import AutoTokenizer

import order_resolver as resolver
import order_tagger as tagger

ORDER_FIELDS = ("action", "soldier_ids", "start", "end", "facing", "group_name")


def load_split(path, limit=None):
    with open(path) as handle:
        examples = [json.loads(line) for line in handle]
    return examples[:limit] if limit else examples


def order_for(action, tokens, tags, context):
    order = resolver.resolve(action, tokens, tags, context)
    return {key: order[key] for key in ORDER_FIELDS}


def evaluate_split(model, tokenizer, examples):
    predictions = tagger.predict(model, tokenizer, examples)
    counts = {"action": 0, "words": 0, "word_total": 0, "labels": 0, "order": 0}
    errors = []
    for example, (action, tags) in zip(examples, predictions):
        counts["action"] += action == example["action"]
        counts["words"] += sum(a == b for a, b in zip(tags, example["tags"]))
        counts["word_total"] += len(tags)
        counts["labels"] += action == example["action"] and tags == example["tags"]
        correct = order_for(action, example["tokens"], tags, example["context"]) == example["order"]
        counts["order"] += correct
        if not correct and len(errors) < 15:
            errors.append({"text": example["text"], "expected": example["action"], "predicted": action,
                           "tags": " ".join("%s/%s" % (token, tag) for token, tag in zip(example["tokens"], tags) if tag != "O")})
    total = len(examples)
    return {"examples": total, "action_accuracy": counts["action"] / total, "word_tag_accuracy": counts["words"] / counts["word_total"],
            "all_labels_correct": counts["labels"] / total, "order_correct": counts["order"] / total, "errors": errors}


def evaluate_cases(model, tokenizer):
    """Score the hand-written evaluator cases with the evaluator's own scorer."""
    import evaluate_sandbox_orders as evaluator

    results = []
    passed = 0
    started = time.perf_counter()
    for request_id, case in enumerate(evaluator.CASES, start=1):
        context = evaluator.context_for_case(case)
        tokens = resolver.tokenize(case["prompt"])
        action, tags = tagger.predict(model, tokenizer, [{"tokens": tokens}])[0]
        order = resolver.resolve(action, tokens, tags, context)
        ok, failures = evaluator.score_response({"request_id": request_id, "mode": "local", "order": order}, case, request_id, context)
        passed += ok
        results.append({"name": case["name"], "prompt": case["prompt"], "passed": ok, "action": action, "failures": failures,
                        "tags": " ".join("%s/%s" % (token, tag) for token, tag in zip(tokens, tags) if tag != "O")})
    seconds = (time.perf_counter() - started) / len(evaluator.CASES)
    return {"passed": passed, "total": len(evaluator.CASES), "seconds_per_case": seconds, "cases": results}


def print_report(report):
    for split in ("dev", "test"):
        print(split, json.dumps({key: round(value, 4) for key, value in report[split].items() if isinstance(value, float)}))
    cases = report["evaluator_cases"]
    print("evaluator cases %d/%d, %.1f ms per case" % (cases["passed"], cases["total"], 1000 * cases["seconds_per_case"]))
    for case in cases["cases"]:
        if not case["passed"]:
            print("  FAIL %s: %r -> %s [%s] %s" % (case["name"], case["prompt"], case["action"], case["tags"], "; ".join(case["failures"])))


def train(args):
    torch.manual_seed(args.seed)
    random.seed(args.seed)
    torch.set_num_threads(args.threads)
    data = Path(args.data)
    train_examples = load_split(data / "train.jsonl", args.max_train)
    dev_examples = load_split(data / "dev.jsonl")
    test_examples = load_split(data / "test.jsonl")
    tokenizer = AutoTokenizer.from_pretrained(args.model)
    model = tagger.OrderTagger.pretrained(args.model)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=0.01)
    steps = args.epochs * ((len(train_examples) + args.batch_size - 1) // args.batch_size)
    warmup = max(1, steps // 20)
    scheduler = torch.optim.lr_scheduler.LambdaLR(optimizer, lambda step: min((step + 1) / warmup, max(0.0, (steps - step) / (steps - warmup))))
    loss_function = nn.CrossEntropyLoss(ignore_index=-100)
    history = []
    for epoch in range(1, args.epochs + 1):
        model.train()
        random.shuffle(train_examples)
        started = time.perf_counter()
        losses = []
        for start in range(0, len(train_examples), args.batch_size):
            batch = train_examples[start:start + args.batch_size]
            encoded, _, actions, tag_labels = tagger.encode(tokenizer, batch)
            action_logits, tag_logits = model(encoded["input_ids"], encoded["attention_mask"])
            loss = loss_function(action_logits, actions) + loss_function(tag_logits.reshape(-1, len(tagger.TAGS)), tag_labels.reshape(-1))
            optimizer.zero_grad()
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            scheduler.step()
            losses.append(loss.item())
        dev = evaluate_split(model, tokenizer, dev_examples)
        record = {"epoch": epoch, "seconds": round(time.perf_counter() - started, 1), "loss": round(statistics.mean(losses), 4),
                  "dev_order_correct": round(dev["order_correct"], 4), "dev_action_accuracy": round(dev["action_accuracy"], 4)}
        history.append(record)
        print(json.dumps(record), flush=True)

    tagger.save(model, tokenizer, args.output, args.model)
    report = {"args": vars(args), "history": history, "dev": evaluate_split(model, tokenizer, dev_examples),
              "test": evaluate_split(model, tokenizer, test_examples), "evaluator_cases": evaluate_cases(model, tokenizer)}
    (Path(args.output) / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print_report(report)


def rescore(args):
    """Score a saved tagger again, for example after a resolver change."""
    torch.set_num_threads(args.threads)
    model, tokenizer, _ = tagger.load(args.output)
    data = Path(args.data)
    report = {"dev": evaluate_split(model, tokenizer, load_split(data / "dev.jsonl")),
              "test": evaluate_split(model, tokenizer, load_split(data / "test.jsonl")),
              "evaluator_cases": evaluate_cases(model, tokenizer)}
    print_report(report)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--data", required=True, help="Directory with train/dev/test JSONL from generate_order_dataset.py")
    parser.add_argument("--output", required=True, help="Directory for the trained tagger")
    parser.add_argument("--model", default="google/bert_uncased_L-4_H-256_A-4", help="Pretrained encoder to fine-tune")
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--threads", type=int, default=8)
    parser.add_argument("--max-train", type=int)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--rescore", action="store_true", help="Score the saved tagger in --output instead of training")
    args = parser.parse_args()
    rescore(args) if args.rescore else train(args)


if __name__ == "__main__":
    main()
