from dotenv import load_dotenv
import random
import anthropic

load_dotenv()

client = anthropic.Anthropic()

def generate_secret_word(category: str, used_words: list[str]) -> str:
    exclude = ""
    if used_words:
        exclude = f" Do not use these words: {', '.join(used_words)}."
    
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=100,
        temperature=1.0,
        messages=[
            {
                "role": "user",
                "content": f"Give me 5 words related to the category '{category}' that would work for a word-guessing game. The words should be specific enough to hint at but not too obvious.{exclude} Return only the words, one per line, nothing else."
            }
        ]
    )
    
    words = message.content[0].text.strip().split("\n")
    return random.choice(words)

if __name__ == "__main__":
    word = generate_secret_word("Ramadan")
    print(word)