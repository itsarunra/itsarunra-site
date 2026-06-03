(function () {
  const postsList = document.getElementById('posts-list');
  const archiveList = document.getElementById('posts-archive');

  if (!postsList || !archiveList) {
    return;
  }

  const archiveBasePath = window.POSTS_ARCHIVE_BASE_PATH || window.location.pathname;
  const dateFormatter = new Intl.DateTimeFormat('en-AU', {
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  });
  const monthFormatter = new Intl.DateTimeFormat('en-AU', {
    month: 'long',
    year: 'numeric'
  });

  function getSelectedMonth() {
    return new URLSearchParams(window.location.search).get('month') || '';
  }

  function getMonthKey(post) {
    return post.date.slice(0, 7);
  }

  function toLocalDate(value) {
    return new Date(`${value}T00:00:00`);
  }

  function sortPosts(posts) {
    return [...posts].sort((a, b) => b.date.localeCompare(a.date));
  }

  function groupByMonth(posts) {
    const groups = new Map();

    for (const post of posts) {
      const key = getMonthKey(post);
      if (!groups.has(key)) {
        groups.set(key, []);
      }
      groups.get(key).push(post);
    }

    return [...groups.entries()]
      .map(([month, groupPosts]) => ({
        month,
        label: monthFormatter.format(toLocalDate(`${month}-01`)),
        posts: sortPosts(groupPosts)
      }))
      .sort((a, b) => b.month.localeCompare(a.month));
  }

  function makeArchiveUrl(month) {
    const url = new URL(archiveBasePath, window.location.origin);

    if (month) {
      url.searchParams.set('month', month);
    }

    return `${url.pathname}${url.search}`;
  }

  function renderArchive(posts, selectedMonth) {
    const groups = groupByMonth(posts);

    for (const group of groups) {
      const item = document.createElement('li');
      const link = document.createElement('a');
      link.href = makeArchiveUrl(group.month);
      link.textContent = `${group.label} (${group.posts.length})`;

      if (group.month === selectedMonth) {
        link.className = 'active';
        link.setAttribute('aria-current', 'page');
      }

      item.appendChild(link);
      archiveList.appendChild(item);
    }
  }

  function renderPosts(posts) {
    if (!posts.length) {
      postsList.innerHTML = '<p class="muted">No posts in this month.</p>';
      return;
    }

    postsList.replaceChildren(...posts.map((post) => {
      const item = document.createElement('p');
      item.className = 'post-item';

      const link = document.createElement('a');
      link.href = post.url;
      link.textContent = post.title;

      const lineBreak = document.createElement('br');
      const date = document.createElement('time');
      date.className = 'muted';
      date.dateTime = post.date;
      date.textContent = dateFormatter.format(toLocalDate(post.date));

      item.append(link, lineBreak, date);
      return item;
    }));
  }

  async function initPostsArchive() {
    try {
      const response = await fetch('/data/posts.json', { cache: 'no-store' });
      const posts = sortPosts(await response.json());
      const selectedMonth = getSelectedMonth();
      const visiblePosts = selectedMonth
        ? posts.filter((post) => getMonthKey(post) === selectedMonth)
        : posts;

      renderArchive(posts, selectedMonth);
      renderPosts(visiblePosts);
    } catch (error) {
      postsList.innerHTML = '<p class="muted">Posts could not be loaded.</p>';
    }
  }

  initPostsArchive();
})();
