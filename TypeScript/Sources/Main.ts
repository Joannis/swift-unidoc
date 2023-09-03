import { Searchbar } from './Searchbar';

function hex(value: number): string {
    return value.toString(16).padStart(2, "0")
}

function nonce(): string {
    const uint64: Uint8Array = new Uint8Array(8);
    return Array.from(window.crypto.getRandomValues(uint64), hex).join('')
}

const login: HTMLElement | null = document.getElementById('login');
const list: HTMLElement | null = document.getElementById('search-results');

if (list !== null) {
    const searchbar: Searchbar = new Searchbar({ list: list });

    const input: HTMLElement | null = document.getElementById('search-input');

    if (input !== null) {
        input.addEventListener('focus',
            (event: Event) => searchbar.focus());
        input.addEventListener('input',
            (event: Event) => searchbar.suggest(event));
        input.addEventListener('keydown',
            (event: KeyboardEvent) => searchbar.navigate(event));
    }

    const form: HTMLElement | null = document.getElementById('search');

    if (form !== null) {
        form.addEventListener('submit',
            (event: Event) => searchbar.follow(event));
    }
}

if (login !== null) {

    const input: HTMLElement = document.createElement('input');
    const state: string = nonce();

    input.setAttribute('type', 'hidden');
    input.setAttribute('name', 'state');
    input.setAttribute('value', state);

    login.appendChild(input);

    document.cookie = 'login_state=' + state + '; Path=/ ; SameSite=Lax';
    // document.cookie = 'login_state=' + state + '; Path=/ ; SameSite=Lax ; Secure';
}
