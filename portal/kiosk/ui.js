window.HunorQuizUI = {
  icon(name='flashlight') {
    const paths={flashlight:'<path d="m8 3 8 0-1 6-1 2v10h-4V11L9 9 8 3Z"/><path d="M9 7h6M10 15h4M12 0v1M3 4l3 2M21 4l-3 2"/>',shield:'<path d="m12 3 8 3v6c0 5-5 8-8 10-3-2-8-5-8-10V6l8-3Z"/><path d="m8 12 3 3 5-6"/>',trophy:'<path d="M8 3h8v7a4 4 0 0 1-8 0V3ZM8 5H4v3a4 4 0 0 0 4 4M16 5h4v3a4 4 0 0 1-4 4M12 14v5M8 21h8"/>',check:'<path d="m5 12 4 4L19 6"/>'};
    return `<svg class="hq-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name]||paths.flashlight}</svg>`;
  }
};
