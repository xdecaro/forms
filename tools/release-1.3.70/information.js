(() => {
  'use strict';

  const diagnostic = document.getElementById('dfi-diagnostic-data');

  if (!diagnostic) {
    return;
  }

  const text = diagnostic.textContent || '';
  const feedback = document.querySelector('[data-dfi-feedback]');
  const copyButton = document.querySelector('[data-dfi-copy]');
  const downloadButton = document.querySelector('[data-dfi-download]');

  const setFeedback = (message) => {
    if (feedback) {
      feedback.textContent = message;
    }
  };

  if (copyButton) {
    copyButton.addEventListener('click', async () => {
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
        } else {
          const textarea = document.createElement('textarea');
          textarea.value = text;
          textarea.setAttribute('readonly', '');
          textarea.style.position = 'fixed';
          textarea.style.opacity = '0';
          document.body.appendChild(textarea);
          textarea.select();
          document.execCommand('copy');
          textarea.remove();
        }

        setFeedback(Joomla.Text._('COM_DECAROFORMS_INFO_DIAGNOSTICS_COPIED'));
      } catch (error) {
        console.error('Forms diagnostics copy failed', error);
        setFeedback(Joomla.Text._('COM_DECAROFORMS_INFO_DIAGNOSTICS_COPY_FAILED'));
      }
    });
  }

  if (downloadButton) {
    downloadButton.addEventListener('click', () => {
      const version = downloadButton.dataset.version || 'unknown';
      const blob = new Blob([text + '\n'], { type: 'text/plain;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `forms-diagnostics-${version}.txt`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
      setFeedback(Joomla.Text._('COM_DECAROFORMS_INFO_DIAGNOSTICS_DOWNLOADED'));
    });
  }
})();
