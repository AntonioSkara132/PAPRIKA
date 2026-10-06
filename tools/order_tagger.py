"""Small BERT order tagger: one action per sentence and one BIO tag per word.

The encoder output for [CLS] feeds a linear action classifier, and the output for
the first sub-word of each word feeds a linear tag classifier. order_resolver turns
the predicted labels into the order the game executes. Needs PyTorch and
transformers; the order service imports this module only for the bert provider.
"""

import json
from pathlib import Path

import torch
from torch import nn
from transformers import AutoConfig, AutoModel, AutoTokenizer

import order_resolver as resolver

ACTIONS = list(resolver.ACTIONS)
TAGS = list(resolver.TAGS)
MAX_PIECES = 128


class OrderTagger(nn.Module):
    def __init__(self, encoder, dropout=0.1):
        super().__init__()
        self.encoder = encoder
        hidden = encoder.config.hidden_size
        self.dropout = nn.Dropout(dropout)
        self.action_head = nn.Linear(hidden, len(ACTIONS))
        self.tag_head = nn.Linear(hidden, len(TAGS))

    @classmethod
    def pretrained(cls, encoder_name):
        return cls(AutoModel.from_pretrained(encoder_name))

    def forward(self, input_ids, attention_mask):
        states = self.dropout(self.encoder(input_ids=input_ids, attention_mask=attention_mask).last_hidden_state)
        return self.action_head(states[:, 0]), self.tag_head(states)


def encode(tokenizer, batch, max_length=MAX_PIECES):
    """Tokenize word lists; label only the first sub-word of each word.

    Returns the encoded batch, the first sub-word position of every word, action
    labels and tag labels (-100 where no tag is learned). Examples without labels
    get action 0 and no tag labels.
    """
    encoded = tokenizer([example["tokens"] for example in batch], is_split_into_words=True, truncation=True,
                        max_length=max_length, padding=True, return_tensors="pt")
    first_piece = []
    tag_labels = []
    for row, example in enumerate(batch):
        positions = [-1] * len(example["tokens"])
        previous = None
        for position, word in enumerate(encoded.word_ids(row)):
            if word is not None and word != previous:
                positions[word] = position
            previous = word
        if -1 in positions:
            raise ValueError("The sentence is too long for the tagger.")
        first_piece.append(positions)
        labels = [-100] * encoded["input_ids"].shape[1]
        if "tags" in example:
            for word, position in enumerate(positions):
                labels[position] = TAGS.index(example["tags"][word])
        tag_labels.append(labels)
    actions = torch.tensor([ACTIONS.index(example["action"]) if "action" in example else 0 for example in batch])
    return encoded, first_piece, actions, torch.tensor(tag_labels)


def predict(model, tokenizer, examples, batch_size=64):
    """Return [(action, tags)] for examples that have "tokens"."""
    model.eval()
    results = []
    with torch.no_grad():
        for start in range(0, len(examples), batch_size):
            batch = examples[start:start + batch_size]
            encoded, first_piece, _, _ = encode(tokenizer, batch)
            action_logits, tag_logits = model(encoded["input_ids"], encoded["attention_mask"])
            for row, positions in enumerate(first_piece):
                tags = [TAGS[index] for index in tag_logits[row, positions].argmax(-1).tolist()]
                results.append((ACTIONS[action_logits[row].argmax().item()], tags))
    return results


def save(model, tokenizer, directory, encoder_name):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), directory / "model.pt")
    tokenizer.save_pretrained(directory)
    model.encoder.config.save_pretrained(directory)
    (directory / "labels.json").write_text(json.dumps({"actions": ACTIONS, "tags": TAGS, "encoder": encoder_name}, indent=2) + "\n")


def load(directory):
    """Load a tagger saved by save(); reads only local files."""
    directory = Path(directory)
    labels = json.loads((directory / "labels.json").read_text())
    if labels["actions"] != ACTIONS or labels["tags"] != TAGS:
        raise ValueError("The saved tagger uses a different action or tag list; retrain it.")
    model = OrderTagger(AutoModel.from_config(AutoConfig.from_pretrained(directory, local_files_only=True)))
    model.load_state_dict(torch.load(directory / "model.pt", map_location="cpu", weights_only=True))
    model.eval()
    return model, AutoTokenizer.from_pretrained(directory, local_files_only=True), labels["encoder"]


def interpret(model, tokenizer, prompt, context):
    """Return the validated seven-field order for one player prompt."""
    tokens = resolver.tokenize(prompt)
    if not tokens:
        return resolver.clarify("Type an order for the soldiers.")
    try:
        action, tags = predict(model, tokenizer, [{"tokens": tokens}])[0]
    except ValueError:
        return resolver.clarify("That order is too long. Give one short order at a time.")
    return resolver.resolve(action, tokens, tags, context)
