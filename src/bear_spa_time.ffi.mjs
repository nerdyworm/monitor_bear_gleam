const minute = 60;
const hour = minute * 60;
const day = hour * 24;
const month = day * 30;

function plural(single, plural, count) {
  let str = count === 1 ? single : plural;
  return str.replace("$", count);
}

export function time_since(date) {
  const input = new Date(date + 'Z');
  let seconds = Math.floor((input - new Date()) / 1000);

  if (Math.abs(seconds) > 60 * 60 * 24) {
    let string = input.toISOString();
    // no sub seconds
    return string.split(".")[0];
  }

  if (seconds === 0) {
    return "now";
  }

  if (seconds > 0 && seconds < 45) {
    return plural(
      `in $ second`,
      `in $ seconds`,
      seconds
    );
  }

  if (seconds > 45 && seconds < minute * 2) {
    return plural(
      `in $ minute`,
      `in $ minutes`,
      1
    );
  }

  if (seconds >= minute * 2 && seconds < hour) {
    return plural(
      `in $ minute`,
      `in $ minutes`,
      Math.floor(seconds / minute)
    );
  }

  // past
  if (seconds < 0 && seconds >= -45) {
    return plural(
      `$ second ago`,
      `$ seconds ago`,
      seconds * -1
    );
  }

  if (seconds < -45 && seconds > minute * 2 * -1) {
    return plural(
      `$ minute ago`,
      `$ minutes ago`,
      Math.floor(seconds / minute) * -1
    );
  }

  if (seconds < minute * 2 && seconds > hour * -1) {
    return plural(
      `$ minute ago`,
      `$ minutes ago`,
      Math.floor((seconds * -1) / minute)
    );
  }

  if (seconds < hour && seconds > hour * 2 * -1) {
    return plural(
      `$ hour ago`,
      `$ hours ago`,
      1
    );
  }

  if (seconds < hour * 2 && seconds > day * -1) {
    return plural(
      `$ hour ago`,
      `$ hours ago`,
      Math.floor((seconds * -1) / hour)
    );
  }


  if (seconds < day && seconds > day * 2 * -1) {
    return plural(
      `yesterday`,
      `yesterday`,
      1
    );
  }

  if (seconds < day * 2 && seconds > month * -1) {
    return plural(
      `$ day ago`,
      `$ days ago`,
      Math.floor((seconds * -1) / day)
    );
  }

  // if (seconds < minute * 2 && seconds > hour * -1) {
  //   return `{seconds} minutes ago`;
  // }

  // less than an hour, show time  ago
  // 
  // let interval = seconds / 31536000;

  // if (interval > 1) {
  //   return Math.floor(interval) + " years";
  // }

  // interval = seconds / 2592000;
  // if (interval > 1) {
  //   return Math.floor(interval) + " months";
  // }

  // interval = seconds / 86400;
  // if (interval > 1) {
  //   return Math.floor(interval) + " days";
  // }

  // interval = seconds / 3600;
  // if (interval > 1) {
  //   return Math.floor(interval) + " hours";
  // }

  // interval = seconds / 60;
  // if (interval > 1) {
  //   return Math.floor(interval) + " minutes";
  // }

  // return Math.floor(seconds) + " seconds";
}


